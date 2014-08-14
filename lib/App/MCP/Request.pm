package App::MCP::Request;

use feature 'state';
use namespace::autoclean;

use Moo;
use App::MCP::Constants    qw( EXCEPTION_CLASS NUL SPC TRUE );
use App::MCP::Functions    qw( extract_lang );
use App::MCP::Session;
use Authen::HTTP::Signature::Parser;
use CGI::Simple::Cookie;
use Class::Usul::Functions qw( class2appdir first_char is_arrayref is_hashref
                               is_member throw trim );
use Class::Usul::Types     qw( ArrayRef BaseType HashRef NonEmptySimpleStr
                               Object SimpleStr Str );
use Convert::SSH2;
use Encode                 qw( decode );
use HTTP::Body;
use HTTP::Status           qw( HTTP_EXPECTATION_FAILED
                               HTTP_INTERNAL_SERVER_ERROR
                               HTTP_REQUEST_ENTITY_TOO_LARGE
                               HTTP_UNAUTHORIZED );
use JSON                   qw( );
use Scalar::Util           qw( blessed weaken );
use Try::Tiny;
use Unexpected::Functions  qw( ChecksumFailure MissingHeader MissingKey
                               SigParserFailure SigVerifyFailure Unspecified );
use URI::http;
use URI::https;

# Public attributes
has 'args'        => is => 'ro',   isa => ArrayRef, default => sub { [] };

has 'base'        => is => 'lazy', isa => Object;

has 'body'        => is => 'lazy', isa => Object;

has 'cookie'      => is => 'lazy', isa => HashRef, builder => sub {
   { CGI::Simple::Cookie->parse( $_[ 0 ]->env->{HTTP_COOKIE} ) || {} } };

has 'domain'      => is => 'lazy', isa => NonEmptySimpleStr,
   builder        => sub { (split m{ : }mx, $_[ 0 ]->host)[ 0 ] };

has 'env'         => is => 'ro',   isa => HashRef, default => sub { {} };

has 'host'        => is => 'lazy', isa => NonEmptySimpleStr, builder => sub {
   my $env        =  $_[ 0 ]->env;
      $env->{ 'HTTP_HOST' } // $env->{ 'SERVER_NAME' } // 'localhost' };

has 'l10n_domain' => is => 'lazy', isa => NonEmptySimpleStr,
   default        => sub { $_[ 0 ]->config->name };

has 'language'    => is => 'lazy', isa => NonEmptySimpleStr,
   builder        => sub { __extract_lang( $_[ 0 ]->locale ) };

has 'locale'      => is => 'lazy', isa => NonEmptySimpleStr;

has 'locales'     => is => 'lazy', isa => ArrayRef;

has 'method'      => is => 'lazy', isa => SimpleStr,
   builder        => sub { lc( $_[ 0 ]->env->{ 'REQUEST_METHOD' } // NUL ) };

has 'params'      => is => 'ro',   isa => HashRef, default => sub { {} };

has 'path'        => is => 'lazy', isa => SimpleStr, builder => sub {
   my $v          =  $_[ 0 ]->env->{ 'PATH_INFO' } // '/';
      $v          =~ s{ \A / }{}mx; $v =~ s{ \? .* \z }{}mx; $v };

has 'protocol'    => is => 'lazy', isa => NonEmptySimpleStr,
   builder        => sub { $_[ 0 ]->env->{ 'SERVER_PROTOCOL' } };

has 'query'       => is => 'lazy', isa => Str, builder => sub {
   my $v          =  $_[ 0 ]->env->{ 'QUERY_STRING' }; $v ? "?${v}" : NUL };

has 'scheme'      => is => 'lazy', isa => NonEmptySimpleStr,
   builder        => sub { $_[ 0 ]->env->{ 'psgi.url_scheme' } // 'http' };

has 'script'      => is => 'lazy', isa => SimpleStr, builder => sub {
   my $v          =  $_[ 0 ]->env->{ 'SCRIPT_NAME' } // '/';
      $v          =~ s{ / \z }{}gmx; $v };

has 'session'     => is => 'lazy', isa => Object, builder => sub {
   App::MCP::Session->new( builder => $_[ 0 ]->usul, env => $_[ 0 ]->env ) },
   handles        => [ qw( authenticated username ) ];

has 'ui_state'    => is => 'lazy', isa => HashRef;

has 'uri'         => is => 'lazy', isa => Object;

has 'usul'        => is => 'ro', isa => BaseType,
   handles        => [ qw( config localize log ) ],
   init_arg       => 'builder', required => TRUE, weak_ref => TRUE;

has 'tunnel_method' => is => 'lazy', isa => NonEmptySimpleStr, builder => sub {
   my $body_method  = delete $_[ 0 ]->body->param->{_method};
   my $query_method = delete $_[ 0 ]->params->{_method};
   my $method       = $body_method || $query_method || 'not_found';
   return (is_arrayref $method) ? lc $method->[ 0 ] : lc $method };

# Private attributes
has '_content'    => is => 'lazy', isa => Str, init_arg => undef;

has '_transcoder' => is => 'lazy', isa => Object,
   builder        => sub { JSON->new }, init_arg => undef;

# Construction
around 'BUILDARGS' => sub {
   my ($orig, $self, @args) = @_; my $attr = {};

   $attr->{builder} = shift @args; $attr->{l10n_domain} = shift @args;

   $attr->{env    } = ($args[ 0 ] and is_hashref $args[ -1 ]) ? pop @args : {};
   $attr->{params } = ($args[ 0 ] and is_hashref $args[ -1 ]) ? pop @args : {};
   $attr->{args   } = (defined $args[ 0 ] && blessed $args[ 0 ])
                    ? [ $args[ 0 ] ]
                    : [ split m{ / }mx, trim $args[ 0 ] || NUL ];

   return $attr;
};

sub BUILD {
   my $self = shift; $self->tunnel_method; # Coz it's lazy and destructive

   return;
}

sub _build_base {
   my $self = shift;
   my $uri  = $self->scheme.'://'.$self->host.$self->script.'/';

   return bless \$uri, 'URI::'.$self->scheme;
}

sub _build_body {
   my $self = shift; my $env = $self->env; my $in = $self->_content;

   my $body = HTTP::Body->new( $env->{CONTENT_TYPE}, length $in );

   length $in or return $body;

   try {
      if ($env->{CONTENT_TYPE} eq 'application/json') {
         $body->{param} = $self->_transcoder->decode( $in );
      }
      else { $body->add( $in ) }
   }
   catch { $self->log->error( $_ ) };

   return __decode_params( $body );
}

sub _build__content {
   my $self = shift; my $env = $self->env; my $content;

   try {
      $env->{CONTENT_LENGTH}
         and $env->{ 'psgi.input' }->read( $content, $env->{CONTENT_LENGTH} );
   }
   catch { $self->log->error( $_ ); $content = undef };

   return $content ? $content : NUL;
}

sub _build_locale {
   my $self = shift; my $locale;

   exists $self->params->{locale}
      and defined  ($locale = $self->params->{locale})
      and is_member $locale,  $self->config->locales
      and return $locale;

   for my $locale (@{ $self->locales }) {
      is_member $locale, $self->config->locales and return $locale;
   }

   return $self->config->locale;
}

sub _build_locales {
   my $self = shift; my $lang = $self->env->{ 'HTTP_ACCEPT_LANGUAGE' } || NUL;

   return [ map    { s{ _ \z }{}mx; $_ }
            map    { join '_', $_->[ 0 ], uc $_->[ 1 ] }
            map    { [ split m{ - }mx, $_ ] }
            map    { ( split m{ ; }mx, $_ )[ 0 ] }
            split m{ , }mx, lc $lang ];
}

sub _build_ui_state {
   my $self = shift; my $attr = {}; my $name = $self->config->prefix.'_state';

   my $cookie = $self->cookie->{ $name } or return $attr;

   for (split m{ \+ }mx, $cookie->value) {
      my ($k, $v) = split m{ ~ }mx, $_; $k and $attr->{ $k } = $v;
   }

   return $attr;
}

sub _build_uri {
   my $self = shift; my $uri = $self->base.$self->path.$self->query;

   return bless \$uri, 'URI::'.$self->scheme;
}

# Public methods
sub authenticate {
   my $self = shift; my $sig;

   try   { $sig = Authen::HTTP::Signature::Parser->new( $self )->parse() }
   catch { throw class => SigParserFailure,
                 error => $_, rv => HTTP_EXPECTATION_FAILED };

   $sig->key_id or throw class => Unspecified,
                         args  => [ 'key id' ], rv => HTTP_EXPECTATION_FAILED;

   if (is_member 'content-sha512', $sig->headers) {
      my $digest = Digest->new( 'SHA-512' ); $digest->add( $self->_content );

      $self->header( 'content-sha512' ) eq $digest->hexdigest
         or throw class => ChecksumFailure,
                  args  => [ $sig->key_id ], rv => HTTP_UNAUTHORIZED;
   }
   elsif ($sig->headers->[ 0 ] ne 'request-line') {
      throw class => MissingHeader,
            args  => [ $sig->key_id ], rv => HTTP_EXPECTATION_FAILED;
   }

   $sig->key( $self->_read_public_key( $sig->key_id ) );

   $sig->verify or throw class => SigVerifyFailure,
                         args  => [ $sig->key_id ], rv => HTTP_UNAUTHORIZED;

   return; # Authentication was successful
}

sub body_params {
   my $self = shift; weaken( $self );

   my $params = $self->body->param; weaken( $params );

   return sub { $self->_get_scrubbed_param( $params, @_ ) };
}

sub header {
   my ($self, $name) = @_; $name =~ s{ [\-] }{_}gmx; $name = uc $name;

   exists $self->env->{ "HTTP_${name}" }
      and return $self->env->{ "HTTP_${name}" };

   return $self->env->{ $name };
}

sub loc {
   my ($self, $key, @args) = @_; my $args = $self->_localize_args( @args );

   $args->{locale} ||= $self->locale;

   return $self->localize( $key, $args );
}

sub loc_default {
   my ($self, $key, @args) = @_; my $args = $self->_localize_args( @args );

   $args->{locale} ||= $self->config->locale;

   return $self->localize( $key, $args );
}

sub query_params {
   my $self = shift; weaken( $self );

   my $params = $self->params; weaken( $params );

   return sub { $self->_get_scrubbed_param( $params, @_ ) };
}

sub uri_for {
   my ($self, $path, $args, $query_params) = @_;

   $args and defined $args->[ 0 ] and $path = join '/', $path, @{ $args };
   first_char $path ne '/' and $path = $self->base.$path;

   my $uri = bless \$path, 'URI::'.$self->scheme;

   $query_params and $uri->query_form( @{ $query_params } );

   return $uri;
}

# Private methods
sub _get_scrubbed_param {
   my ($self, $params, $name, $opts) = @_; $opts = { %{ $opts // {} } };

   $opts->{max_length} //= $self->config->max_asset_size;
   $opts->{scrubber  } //= $self->config->scrubber;

   $opts->{multiple} and return
      [ map { $opts->{raw} ? $_ : __scrub_value( $name, $_, $opts ) }
           @{ __get_defined_values( $params, $name, $opts ) } ];

   my $v = __get_defined_value( $params, $name, $opts );

   return $opts->{raw} ? $v : __scrub_value( $name, $v, $opts );
}

sub _localize_args {
   my ($self, @args) = @_; my $car = $args[ 0 ];

   my $args = (is_hashref $car) ? { %{ $car } }
            : { params => (is_arrayref $car) ? $car : [ @args ] };

   $args->{domain_names} ||= [ DEFAULT_L10N_DOMAIN, $self->l10n_domain ];
   return $args;
}

sub _read_public_key {
   my ($self, $key_id) = @_; state $cache //= {};

   my $key      = $cache->{ $key_id }; $key and return $key;
   my $ssh_dir  = $self->config->my_home->catdir( '.ssh' );
   my $prefix   = class2appdir $self->config->appclass;
   my $key_file = $ssh_dir->catfile( "${prefix}_${key_id}.pub" );

   try   { $key = Convert::SSH2->new( $key_file->all )->format_output }
   catch { throw class => MissingKey, error => $_, rv => HTTP_UNAUTHORIZED };

   return $cache->{ $key_id } = $key;
}

# Private functions
sub __decode_params {
   my $body = shift;

   for my $k (keys %{ $body->param }) {
      if (is_arrayref $body->param->{ $k }) {
         $body->param->{ $k } = [ map { decode( 'UTF-8', $_  ) }
                                     @{ $body->param->{ $k } } ];
      }
      else { $body->param->{ $k } = decode( 'UTF-8', $body->param->{ $k } ) }
   }

   return $body;
}

sub __defined_or_throw {
   my ($k, $v, $opts) = @_;

   defined $k or throw class => Unspecified, args => [ 'parameter name' ],
                          rv => HTTP_INTERNAL_SERVER_ERROR, level => 5;

   $opts->{optional} or defined $v
      or throw class => Unspecified, args => [ $k ],
                  rv => HTTP_EXPECTATION_FAILED, level => 5;
   return $v;
}

sub __get_defined_value {
   my ($params, $name, $opts) = @_;

   my $v = __defined_or_throw( $name, $params->{ $name }, $opts );

   is_arrayref $v and $v = $v->[ 0 ];

   return __defined_or_throw( $name, $v, $opts );
}

sub __get_defined_values {
   my ($params, $name, $opts) = @_;

   my $v = __defined_or_throw( $name, $params->{ $name }, $opts );

   is_arrayref $v or $v = [ $v ];

   return $v;
}

sub __scrub_value {
   my ($name, $v, $opts) = @_; my $pattern = $opts->{scrubber}; my $len;

   $pattern and defined $v and $v =~ s{ $pattern }{}gmx;

   $opts->{optional} or $opts->{allow_null} or $len = length $v
      or  throw class => Unspecified, args => [ $name ], level => 4,
                   rv => HTTP_EXPECTATION_FAILED;

   $len and $len > $opts->{max_length}
      and throw error => 'Parameter [_1] size [_2] too big',
                 args => [ $name, $len ], level => 4,
                   rv => HTTP_REQUEST_ENTITY_TOO_LARGE;
   return $v;
}

1;

__END__

=pod

=encoding utf8

=head1 Name

App::MCP::Request - Represents the request sent from the client to the server

=head1 Synopsis

   use App::MCP::Request;
   # Brief but working code examples

=head1 Description

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=item C<args>

An array ref of the args supplied with the URI

=item C<base>

A non empty simple string which is the base of the requested URI

=item C<cookie>

A hash ref of cookies supplied with the request

=item C<domain>

A non empty simple string which is the domain of the request

=item C<env>

A hash ref, the L<Plack> request env

=item C<locale>

Defaults to the C<LANG> constant (en)

=item C<params>

A hash ref of parameters supplied with the request

=item C<path>

Taken from the request path, this should be the same as the
C<mount_point> configuration attribute

=back

=head1 Subroutines/Methods

=head2 loc

=head2 uri_for

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<CGI::Simple::Cookie>

=item L<Class::Usul>

=item L<Moo>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module. Please report problems to
http://rt.cpan.org/NoAuth/Bugs.html?Dist=Doh.
Patches are welcome

=head1 Acknowledgements

Larry Wall - For the Perl programming language

=head1 Author

Peter Flanigan, C<< <pjfl@cpan.org> >>

=head1 License and Copyright

Copyright (c) 2014 Peter Flanigan. All rights reserved

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See L<perlartistic>

This program is distributed in the hope that it will be useful,
but WITHOUT WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE

=cut

# Local Variables:
# mode: perl
# tab-width: 3
# End:
