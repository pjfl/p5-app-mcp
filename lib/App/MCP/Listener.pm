# @(#)$Ident: Listener.pm 2014-01-19 15:47 pjf ;

package App::MCP::Listener;

use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.3.%d', q$Rev: 12 $ =~ /\d+/gmx );

use App::MCP::Application;
use App::MCP::Constants;
use App::MCP::Model::Schedule;
use App::MCP::Request;
use App::MCP::View::HTML;
use Class::Usul;
use Class::Usul::Functions  qw( exception find_apphome get_cfgfiles );
use Class::Usul::Types      qw( BaseType HashRef NonZeroPositiveInt Object );
use HTTP::Status            qw( HTTP_INTERNAL_SERVER_ERROR HTTP_NOT_FOUND );
use Plack::Builder;
use TryCatch;
use Web::Simple;

# Public attributes
has 'port'   => is => 'lazy', isa => NonZeroPositiveInt, builder => sub {
   $ENV{MCP_LISTENER_PORT} || $_[ 0 ]->usul->config->port };

# Private attributes
has '_api'   => is => 'lazy', isa => Object, reader => 'api', builder => sub {
   App::MCP::Application->new
      ( builder   => $_[ 0 ]->usul, port => $_[ 0 ]->port ) };

has '_usul'  => is => 'lazy', isa => BaseType,
   handles   => [ 'log' ], reader => 'usul', builder => sub {
      my $self = shift;
      my $attr = {
         config       => { appclass => 'App::MCP', name => 'listener' },
         config_class => 'App::MCP::Config',
         debug        => $ENV{MCP_DEBUG} || FALSE };
      my $conf = $attr->{config};

      $conf->{home    } = find_apphome $conf->{appclass};
      $conf->{cfgfiles} = get_cfgfiles $conf->{appclass}, $conf->{home};

      return Class::Usul->new( $attr ) };

has '_views' => is => 'lazy', isa => HashRef[Object], builder => sub { {
   'json'    => App::MCP::View::JSON->new,
   'html'    => App::MCP::View::HTML->new( builder => $_[ 0 ]->usul ),
   'text'    => App::MCP::View::Text->new, } };

has '_web'   => is => 'lazy', isa => Object, reader => 'web', builder => sub {
   App::MCP::Model::Schedule->new( builder => $_[ 0 ]->usul ) };

# Construction
around 'to_psgi_app' => sub {
   my ($orig, $self, @args) = @_; my $app = $orig->( $self, @args );

   my $debug  = $ENV{PLACK_ENV} eq 'development' ? TRUE : FALSE;
   my $conf   = $self->usul->config;
   my $point  = $conf->mount_point;
   my $logger = $self->usul->log;

   builder {
      mount "${point}" => builder {
         enable 'LogErrors', logger => sub {
            my $p = shift; my $level = $p->{level};
            $logger->$level( $p->{message} ) };
         enable 'Deflater',
            content_type    => [ qw( text/css text/html text/javascript
                                     application/javascript ) ],
            vary_user_agent => TRUE;
         # TODO: User Plack::Middleware::Static::Minifier
         enable 'Static',
            path => qr{ \A / (css | img | js | less) }mx, root => $conf->root;
         enable_if { $debug } 'Debug';
         $app;
      };
   };
};

# Public methods
sub dispatch_request {
   sub (POST + /api/event/*) {
      return shift->_action( TRUE,  qw( json api create_event ), @_ );
   },
   sub (POST + /api/job/*) {
      return shift->_action( TRUE,  qw( json api create_job ), @_ );
   },
   sub (POST + /api/session/*) {
      return shift->_action( TRUE,  qw( json api find_or_create_session ), @_ );
   },
   sub (GET  + /api/state/*) {
      return shift->_action( FALSE, qw( json api snapshot_state ), @_ );
   },
   sub (GET  + /state) {
      return shift->_action( FALSE, qw( html web state_diagram ), @_ );
   },
   sub {
      [ HTTP_NOT_FOUND, [ 'Content-Type', 'text/plain' ], [ "Not found\n" ] ];
   };
}

# Private methods
sub _action {
   my ($self, $auth, $type, $model, $method, @args) = @_; my ($req, $res);

   try {
      $req = App::MCP::Request->new( $self->usul, @args );
      $auth and $req = $req->authenticate;
      $res = $self->_render( $type, $req, $self->$model->$method( $req ) );
   }
   catch ($e) {
      $e->can( 'rv' ) or $e = exception error => $e,
                                           rv => HTTP_INTERNAL_SERVER_ERROR;
      $self->log->error( $e );
      $res = $self->_render( 'text', undef, {
         code => $e->rv, content => "${e}" } );
   }

   return $res;
}

sub _render {
   my ($self, $type, $req, $stash) = @_;

   return [ $stash->{code}, $self->_views->{ $type }->render( $req, $stash ) ];
}

package # Hide from indexer
   App::MCP::View::JSON;

use Moo;
use Class::Usul::Types qw( Object );
use JSON               qw();

has 'transcoder' => is => 'lazy', isa => Object, builder => sub { JSON->new };

sub render {
   my ($self, $req, $stash) = @_;

   my $content = $self->transcoder->encode( $stash->{content} );

   return [ 'Content-Type' => 'application/json' ], [ $content ];
}

package # Hide from indexer
   App::MCP::View::Text;

use Scalar::Util qw( blessed );

sub new {
   return bless {}, blessed $_[ 0 ] || $_[ 0 ];
}

sub render {
   return [ 'Content-Type' => 'text/plain' ], [ $_[ 2 ]->{content} ];
}

1;

__END__

=pod

=head1 Name

App::MCP::Listener - <One-line description of module's purpose>

=head1 Version

This documents version v0.3.$Rev: 12 $

=head1 Synopsis

   use App::MCP::Listener;
   # Brief but working code examples

=head1 Description

=head1 Configuration and Environment

=head1 Subroutines/Methods

=head1 Diagnostics

=head1 Dependencies

=over 3

=item L<Class::Usul>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module.
Please report problems to the address below.
Patches are welcome

=head1 Acknowledgements

Larry Wall - For the Perl programming language

=head1 Author

Peter Flanigan, C<< <Support at RoxSoft dot co dot uk> >>

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
