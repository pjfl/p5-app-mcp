# @(#)Ident: Request.pm 2013-11-02 18:45 pjf ;

package App::MCP::Request;

use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.3.%d', q$Rev: 7 $ =~ /\d+/gmx );

use CGI::Simple::Cookie;
use Class::Usul::Constants;
use Class::Usul::Functions qw( is_arrayref is_hashref trim );
use Class::Usul::Types     qw( ArrayRef HashRef NonEmptySimpleStr
                               Object SimpleStr );
use JSON                   qw( );
use Moo;
use TryCatch;

# Public attributes
has 'args'   => is => 'ro',   isa => ArrayRef, default => sub { [] };

has 'base'   => is => 'ro',   isa => NonEmptySimpleStr, required => TRUE;

has 'body'   => is => 'lazy', isa => HashRef;

has 'cookie' => is => 'lazy', isa => HashRef, builder => sub {
   { CGI::Simple::Cookie->parse( $_[ 0 ]->_env->{HTTP_COOKIE} ) } };

has 'domain' => is => 'ro',   isa => NonEmptySimpleStr, required => TRUE;

has 'locale' => is => 'lazy', isa => NonEmptySimpleStr,
   builder   => sub { $_[ 0 ]->config->locale };

has 'params' => is => 'ro',   isa => HashRef, default => sub { {} };

has 'path'   => is => 'ro',   isa => SimpleStr, default => NUL;

# Private attributes
has '_env'        => is => 'ro',   isa => HashRef, default => sub { {} },
   init_arg       => 'env';

has '_transcoder' => is => 'lazy', isa => Object, builder => sub { JSON->new },
   init_arg       => undef;

has '_usul'       => is => 'ro',   isa => Object,
   handles        => [ qw( config debug localize log ) ],
   init_arg       => 'builder', required => TRUE, weak_ref => TRUE;

# Construction
around 'BUILDARGS' => sub {
   my ($orig, $self, @args) = @_; my $attr = {};

   $attr->{builder} = shift @args;
   $attr->{env    } = (is_hashref $args[ -1 ]) ? pop @args : {};
   $attr->{params } = (is_hashref $args[ -1 ]) ? pop @args : {};
   $attr->{args   } = [ split m{ / }mx, trim $args[ 0 ] || NUL ];

   my $env  = $attr->{env};
   my $prot = lc( (split m{ / }mx, $env->{SERVER_PROTOCOL} || 'HTTP')[ 0 ] );
   my $path = $env->{SCRIPT_NAME} || '/'; $path =~ s{ / \z }{}gmx;
   my $host = $env->{HTTP_HOST} || 'localhost';

   $attr->{base   } = $prot.'://'.$host.$path.'/';
   $attr->{domain } = (split m{ : }mx, $host)[ 0 ];
   $attr->{path   } = $path;
   return $attr;
};

# Public methods
sub loc {
   my ($self, $key, @args) = @_; my $car = $args[ 0 ];

   my $args = (is_hashref $car) ? { %{ $car } }
            : { params => (is_arrayref $car) ? $car : [ @args ] };

   $args->{domain_names} ||= [ DEFAULT_L10N_DOMAIN, $self->config->name ];
   $args->{locale      } ||= $self->locale;

   return $self->localize( $key, $args );
}

sub uri_for {
   my ($self, $args) = @_; return $self->base.$args;
}

# Private methods
sub _build_body {
   my $self = shift; my $env = $self->_env; my $body = {}; my $buf;

   try {
      $env->{CONTENT_LENGTH}
         and $env->{ 'psgi.input' }->read( $buf, $env->{CONTENT_LENGTH} );
      $buf and $body = $self->_transcoder->decode( $buf );
   }
   catch ($e) { $self->debug and $self->log->debug( $e ); $body = {} }

   return $body;
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

=head1 Version

This documents version v0.3.$Rev: 7 $ of L<App::MCP::Request>

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

Copyright (c) 2013 Peter Flanigan. All rights reserved

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
