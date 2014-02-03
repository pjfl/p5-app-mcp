package App::MCP::Listener;

use namespace::sweep;

use App::MCP::Constants;
use App::MCP::Model::API;
use App::MCP::Model::Form;
use App::MCP::Request;
use App::MCP::View::HTML;
use App::MCP::View::JSON;
use App::MCP::View::XML;
use Class::Usul;
use Class::Usul::Functions  qw( exception find_apphome get_cfgfiles throw );
use Class::Usul::Types      qw( BaseType HashRef NonZeroPositiveInt Object );
use HTTP::Status            qw( HTTP_BAD_REQUEST HTTP_FOUND
                                HTTP_INTERNAL_SERVER_ERROR
                                HTTP_METHOD_NOT_ALLOWED );
use Plack::Builder;
use TryCatch;
use Web::Simple;

# Public attributes
has 'port'    => is => 'lazy', isa => NonZeroPositiveInt, builder => sub {
      $ENV{MCP_LISTENER_PORT} || $_[ 0 ]->usul->config->port
   };

# Private attributes
has '_models' => is => 'lazy', isa => HashRef[Object], reader => 'models',
   builder    => sub { {
      'api'   => App::MCP::Model::API->new ( builder => $_[ 0 ]->usul,
                                             port    => $_[ 0 ]->port ),
      'form'  => App::MCP::Model::Form->new( builder => $_[ 0 ]->usul ),
   } };

has '_usul'   => is => 'lazy', isa => BaseType, reader => 'usul',
   handles    => [ 'log' ], builder => sub {
      my $self = shift;
      my $attr = {
         config       => { appclass => 'App::MCP', name => 'listener' },
         config_class => 'App::MCP::Config',
         debug        => $ENV{MCP_DEBUG} || FALSE };
      my $conf = $attr->{config};

      $conf->{home    } = find_apphome $conf->{appclass};
      $conf->{cfgfiles} = get_cfgfiles $conf->{appclass}, $conf->{home};

      return Class::Usul->new( $attr );
   };

has '_views'  => is => 'lazy', isa => HashRef[Object], reader => 'views',
   builder    => sub { {
      'json'  => App::MCP::View::JSON->new,
      'html'  => App::MCP::View::HTML->new( builder => $_[ 0 ]->usul ),
      'xml'   => App::MCP::View::XML->new,
   } };

# Construction
around 'to_psgi_app' => sub {
   my ($orig, $self, @args) = @_; my $app = $orig->( $self, @args );

   my @types  = (qw(text/css text/html text/javascript application/javascript));
   my $debug  = $ENV{PLACK_ENV} eq 'development' ? TRUE : FALSE;
   my $conf   = $self->usul->config;
   my $point  = $conf->mount_point;
   my $logger = $self->usul->log;
   my $root   = $conf->root;
   my $secret = $conf->salt;

   builder {
      mount "${point}" => builder {
         enable "LogDispatch", logger => $logger;
         enable 'Deflater',
            content_type => [ @types ], vary_user_agent => TRUE;
         # TODO: User Plack::Middleware::Static::Minifier
         enable 'Static',
            path => qr{ \A / (css | img | js | less) }mx, root => $root;
         # TODO: Need to add domain from the request which we dont have yet
         enable 'Session::Cookie',
            expires     => 7_776_000, httponly => TRUE,
            path        => $point,    secret   => $secret,
            session_key => 'mcp_session';
         enable_if { $debug } 'Debug';
         $app;
      };
   };
};

# Public methods
sub dispatch_request {
   sub (POST + /api/event/*) {
      return shift->_execute( qw( json api  create_event ), @_ );
   },
   sub (POST + /api/job/*) {
      return shift->_execute( qw( json api  create_job ), @_ );
   },
   sub (POST + /api/session/*) {
      return shift->_execute( qw( json api  find_or_create_session ), @_ );
   },
   sub (GET  + /api/state/*) {
      return shift->_execute( qw( json api  snapshot_state ), @_ );
   },
   sub (POST + (/job/* | /job) + ?*) {
      return shift->_execute( qw( html form job_action ), @_ );
   },
   sub (GET  + (/job/* | /job) + ?*) {
      return shift->_execute( qw( html form job ), @_ );
   },
   sub (GET  + /job_chooser + ?*) {
      return shift->_execute( qw( xml  form job_chooser ), @_ );
   },
   sub (GET  + /job_grid_rows + ?*) {
      return shift->_execute( qw( xml  form job_grid_rows ), @_ );
   },
   sub (GET  + /job_grid_table + ?*) {
      return shift->_execute( qw( xml  form job_grid_table ), @_ );
   },
   sub (GET  + /state) {
      return shift->_execute( qw( html form state_diagram ), @_ );
   },
   sub () {
      [ HTTP_METHOD_NOT_ALLOWED, __plain_header(), [ 'Method not allowed' ] ];
   };
}

# Private methods
sub _execute {
   my ($self, $view, $model, $method, @args) = @_;

   my $req = App::MCP::Request->new( $self->usul, $model, @args ); my $res;

   try {
      $method =~ m{ _action \z }mx
         and $method = $self->_modify( $method, $req );

      my $stash = $self->models->{ $model }->$method( $req );

      exists $stash->{redirect} and $res = $self->_redirect( $req, $stash );

      $res or $res = $self->views->{ $view }->serialize( $req, $stash )
           or throw error => 'View [_1] returned false', args => [ $view ];
   }
   catch ($e) { $res = $self->_render_exception( $view, $model, $req, $e ) }

   return $res;
}

sub _modify {
   my ($self, $method, $req) = @_;

   my $action = $req->body->param->{_method} || NUL;

   $action and $action = lc "_${action}"; $method =~ s{ _action \z }{$action}mx;

   return $method;
}

sub _redirect {
   my ($self, $req, $stash) = @_;

   my $redirect = $stash->{redirect};
   my $code     = $redirect->{code} || HTTP_FOUND;
   my $tuple    = $redirect->{message};

   $tuple and $req->session->{status_message} = $req->loc( @{ $tuple } );

   return [ $code, [ 'Location', $redirect->{location} ], [] ];
}

sub _render_exception {
   my ($self, $view, $model, $req, $e) = @_; $self->log->error( "${e}" );

   $e->can( 'rv' ) or $e = exception error => "${e}", rv => HTTP_BAD_REQUEST;

   my $res;

   try {
      my $stash = $self->models->{ $model }->exception_handler( $req, $e );

      $res = $self->views->{ $view }->serialize( $req, $stash )
          or throw error => 'View [_1] returned false', args => [ $view ];
   }
   catch ($render_error) { $res = __internal_server_error( $e, $render_error ) }

   return $res;
}

# Private functions
sub __internal_server_error {
   my ($e, $render_error) = @_;

   my $message = "Original error: ${e}\r\nRendering error: ${render_error}";

   return [ HTTP_INTERNAL_SERVER_ERROR, __plain_header(), [ $message ] ];
}

sub __plain_header {
   return [ 'Content-Type', 'text/plain' ];
}

1;

__END__

=pod

=head1 Name

App::MCP::Listener - <One-line description of module's purpose>

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
