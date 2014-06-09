package App::MCP::Request;

use 5.010001;
use namespace::sweep;

use Moo;
use App::MCP::Constants;
use Authen::HTTP::Signature::Parser;
use CGI::Simple::Cookie;
use Class::Usul::Functions qw( class2appdir first_char is_arrayref is_hashref
                               is_member throw trim );
use Class::Usul::Types     qw( ArrayRef HashRef NonEmptySimpleStr
                               Object SimpleStr Str );
use Convert::SSH2;
use HTTP::Body;
use HTTP::Status           qw( HTTP_EXPECTATION_FAILED HTTP_UNAUTHORIZED );
use JSON                   qw( );
use TryCatch;
use Unexpected::Functions  qw( ChecksumFailure MissingHeader MissingKey
                               SigParserFailure SigVerifyFailure Unspecified );
use URI::http;
use URI::https;

extends q(App::MCP);

# Public attributes
has 'args'        => is => 'ro',   isa => ArrayRef, default => sub { [] };

has 'base'        => is => 'ro',   isa => Object, required => TRUE;

has 'body'        => is => 'lazy', isa => Object, init_arg => undef;

has 'cookie'      => is => 'lazy', isa => HashRef, builder => sub {
   { CGI::Simple::Cookie->parse( $_[ 0 ]->_env->{HTTP_COOKIE} ) || {} } };

has 'domain'      => is => 'ro',   isa => NonEmptySimpleStr, required => TRUE;

has 'l10n_domain' => is => 'ro',   isa => NonEmptySimpleStr,
   default        => sub { $_[ 0 ]->config->name };

has 'locale'      => is => 'lazy', isa => NonEmptySimpleStr, init_arg => undef;

has 'method'      => is => 'lazy', isa => NonEmptySimpleStr,
   builder        => sub { lc $_[ 0 ]->_env->{ 'REQUEST_METHOD' } };

has 'params'      => is => 'ro',   isa => HashRef, default => sub { {} };

has 'path'        => is => 'ro',   isa => SimpleStr, default => NUL;

has 'protocol'    => is => 'lazy', isa => SimpleStr,
   builder        => sub { $_[ 0 ]->_env->{ 'SERVER_PROTOCOL' } };

has 'scheme'      => is => 'ro',   isa => NonEmptySimpleStr;

has 'session'     => is => 'lazy', isa => HashRef,
   builder        => sub { $_[ 0 ]->_env->{ 'psgix.session' } // {} };

has 'tunnel_method' => is => 'lazy', isa => NonEmptySimpleStr,
   builder        => sub {
         delete $_[ 0 ]->body->param->{_method}
      || delete $_[ 0 ]->params->{_method} || 'not_found' };

has 'ui_state'    => is => 'lazy', isa => HashRef;

has 'uri'         => is => 'ro',   isa => Object, required => TRUE;

# Private attributes
has '_content'    => is => 'lazy', isa => Str, init_arg => undef;

has '_env'        => is => 'ro',   isa => HashRef, default => sub { {} },
   init_arg       => 'env';

has '_transcoder' => is => 'lazy', isa => Object,
   builder        => sub { JSON->new }, init_arg => undef;

# Construction
around 'BUILDARGS' => sub {
   my ($orig, $self, @args) = @_; my $attr = {};

   $attr->{builder} = shift @args; $attr->{l10n_domain} = shift @args;

   $attr->{env    } = ($args[ 0 ] and is_hashref $args[ -1 ]) ? pop @args : {};
   $attr->{params } = ($args[ 0 ] and is_hashref $args[ -1 ]) ? pop @args : {};
   $attr->{args   } = [ split m{ / }mx, trim $args[ 0 ] // NUL ];

   my $env       = $attr->{env};
   my $scheme    = $attr->{scheme} = $env->{ 'psgi.url_scheme' } || 'http';
   my $host      = $env->{ 'HTTP_HOST'   } || $env->{ 'SERVER_NAME' };
   my $script    = $env->{ 'SCRIPT_NAME' } || '/'; $script =~ s{ / \z }{}gmx;
   my $path_info = $env->{ 'PATH_INFO'   };
      $path_info =~ s{ \A / }{}mx; $path_info =~ s{ \? .* \z }{}mx;
   my $query     = $env->{ 'QUERY_STRING' } ? '?'.$env->{ 'QUERY_STRING' } : '';
   my $base_uri  = "${scheme}://${host}${script}/";
   my $req_uri   = "${base_uri}${path_info}${query}";
   my $uri_class = "URI::${scheme}";

   $attr->{path   } = $script;
   $attr->{uri    } = bless \$req_uri,  $uri_class;
   $attr->{base   } = bless \$base_uri, $uri_class;
   $attr->{domain } = (split m{ : }mx, $host)[ 0 ];
   return $attr;
};

sub _build_body {
   my $self = shift; my $env = $self->_env; my $in = $self->_content;

   my $body = HTTP::Body->new( $env->{CONTENT_TYPE}, length $in );

   length $in or return $body;

   try {
      if ($env->{CONTENT_TYPE} eq 'application/json') {
         $body->{param} = $self->_transcoder->decode( $in );
      }
      else { $body->add( $in ) }
   }
   catch ($e) { $self->log->error( $e ) }

   return $body;
}

sub _build__content {
   my $self = shift; my $env = $self->_env; my $content;

   try {
      $env->{CONTENT_LENGTH}
         and $env->{ 'psgi.input' }->read( $content, $env->{CONTENT_LENGTH} );
   }
   catch ($e) { $self->log->error( $e ); $content = undef }

   return $content ? $content : NUL;
}

sub _build_locale {
   my $self = shift;

   for my $locale (@{ $self->_acceptable_locales }) {
      is_member $locale, $self->config->locales and return $locale;
   }

   return $self->config->locale;
}

sub _build_ui_state {
   my $self = shift; my $attr = {}; my $name = $self->config->prefix.'_state';

   my $cookie = $self->cookie->{ $name } or return $attr;

   for (split m{ \+ }mx, $cookie->value) {
      my ($k, $v) = split m{ ~ }mx, $_; $k and $attr->{ $k } = $v;
   }

   return $attr;
}

# Public methods
sub authenticate {
   my $self = shift; my $sig;

   try        { $sig = Authen::HTTP::Signature::Parser->new( $self )->parse() }
   catch ($e) { throw class => SigParserFailure,
                      error => $e, rv => HTTP_EXPECTATION_FAILED }

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

sub header {
   my ($self, $name) = @_; $name =~ s{ [\-] }{_}gmx; $name = uc $name;

   exists $self->_env->{ "HTTP_${name}" }
      and return $self->_env->{ "HTTP_${name}" };

   return $self->_env->{ $name };
}

sub loc {
   my ($self, $key, @args) = @_; my $car = $args[ 0 ];

   my $args = (is_hashref $car) ? { %{ $car } }
            : { params => (is_arrayref $car) ? $car : [ @args ] };

   $args->{domain_names} ||= [ DEFAULT_L10N_DOMAIN, $self->l10n_domain ];
   $args->{locale      } ||= $self->locale;

   return $self->localize( $key, $args );
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
sub _acceptable_locales {
   my $self = shift; my $lang = $self->_env->{ 'HTTP_ACCEPT_LANGUAGE' } || NUL;

   return [ map    { s{ _ \z }{}mx; $_ }
            map    { join '_', $_->[ 0 ], uc $_->[ 1 ] }
            map    { [ split m{ - }mx, $_ ] }
            map    { ( split m{ ; }mx, $_ )[ 0 ] }
            split m{ , }mx, lc $lang ];
}

sub _read_public_key {
   my ($self, $key_id) = @_; state $cache //= {};

   my $key      = $cache->{ $key_id }; $key and return $key;
   my $ssh_dir  = $self->config->my_home->catdir( '.ssh' );
   my $prefix   = class2appdir $self->config->appclass;
   my $key_file = $ssh_dir->catfile( "${prefix}_${key_id}.pub" );

   try        { $key = Convert::SSH2->new( $key_file->all )->format_output }
   catch ($e) { throw class => MissingKey, error => $e,
                      rv    => HTTP_UNAUTHORIZED }

   return $cache->{ $key_id } = $key;
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
