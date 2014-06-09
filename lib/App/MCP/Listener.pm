package App::MCP::Listener;

use namespace::sweep;

use App::MCP::Constants;
use App::MCP::Controller::API;
use App::MCP::Controller::Forms;
use App::MCP::Controller::Root;
use App::MCP::Model::API;
use App::MCP::Model::Job;
use App::MCP::Model::Root;
use App::MCP::Model::State;
use App::MCP::Request;
use App::MCP::View::HTML;
use App::MCP::View::JSON;
use App::MCP::View::XML;
use Class::Usul;
use Class::Usul::Functions qw( exception find_apphome get_cfgfiles throw );
use Class::Usul::Types     qw( ArrayRef BaseType HashRef
                               NonZeroPositiveInt Object );
use HTTP::Status           qw( HTTP_BAD_REQUEST HTTP_FOUND
                               HTTP_INTERNAL_SERVER_ERROR );
use Plack::Builder;
use TryCatch;
use Web::Simple;

# Public attributes
has 'port' => is => 'lazy', isa => NonZeroPositiveInt, builder => sub {
      $ENV{MCP_LISTENER_PORT} || $_[ 0 ]->usul->config->port
   };

# Private attributes
has '_usul' => is => 'lazy', isa => BaseType, reader => 'usul',
   handles  => [ 'log' ], builder => sub {
      my $self = shift;
      my $attr = {
         config       => { appclass => 'App::MCP', name => 'listener' },
         config_class => 'App::MCP::Config',
         debug        => $ENV{MCP_DEBUG} // FALSE };
      my $conf = $attr->{config};

      $conf->{home    } = find_apphome $conf->{appclass};
      $conf->{cfgfiles} = get_cfgfiles $conf->{appclass}, $conf->{home};

      return Class::Usul->new( $attr );
   };

has '_controllers' => is => 'lazy', isa => ArrayRef[Object],
   reader     => 'controllers', builder => sub { [
      App::MCP::Controller::API->new,
      App::MCP::Controller::Forms->new,
      App::MCP::Controller::Root->new,
   ] };

has '_models' => is => 'lazy', isa => HashRef[Object], reader => 'models',
   builder    => sub { {
      'api'   => App::MCP::Model::API->new  ( builder => $_[ 0 ]->usul,
                                              port    => $_[ 0 ]->port ),
      'job'   => App::MCP::Model::Job->new  ( builder => $_[ 0 ]->usul ),
      'root'  => App::MCP::Model::Root->new ( builder => $_[ 0 ]->usul ),
      'state' => App::MCP::Model::State->new( builder => $_[ 0 ]->usul ),
   } };

has '_views'  => is => 'lazy', isa => HashRef[Object], reader => 'views',
   builder    => sub { {
      'html'  => App::MCP::View::HTML->new( builder => $_[ 0 ]->usul ),
      'json'  => App::MCP::View::JSON->new,
      'xml'   => App::MCP::View::XML->new,
   } };

# Construction
around 'to_psgi_app' => sub {
   my ($orig, $self, @args) = @_; my $app = $orig->( $self, @args );

   my @types  = (qw(text/css text/html text/javascript application/javascript));
   my $conf   = $self->usul->config;
   my $debug  = $self->usul->debug;
   my $point  = $conf->mount_point;
   my $logger = $self->usul->log;
   my $root   = $conf->root;
   my $secret = $conf->salt.$self->models->{root}->get_connect_info->[ 2 ];

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
   return map { $_->dispatch_request } @{ $_[ 0 ]->controllers };
}

sub execute {
   my ($self, $view, $model, $method, @args) = @_; my ($req, $res);

   try        { $req = App::MCP::Request->new( $self->usul, $model, @args ) }
   catch ($e) { return __internal_server_error( $e ) }

   try {
      $method eq 'from_request' and $method = $req->tunnel_method.'_action';

      my $stash = $self->models->{ $model }->execute( $method, $req );

      exists $stash->{redirect} and $res = $self->_redirect( $req, $stash );

      $res or $res = $self->views->{ $view }->serialize( $req, $stash )
           or throw error => 'View [_1] returned false', args => [ $view ];
   }
   catch ($e) { return $self->_render_exception( $view, $model, $req, $e ) }

   return $res;
}

# Private methods
sub _redirect {
   my ($self, $req, $stash) = @_; my $code = $stash->{code} || HTTP_FOUND;

   my $redirect = $stash->{redirect}; my $message = $redirect->{message};

   $message and $req->session->{status_message} = $req->loc( @{ $message } );

   return [ $code, [ 'Location', $redirect->{location} ], [] ];
}

sub _render_exception {
   my ($self, $view, $model, $req, $e) = @_; my $res;

   my $msg = "${e}"; chomp $msg; $self->log->error( $msg );

   $e->can( 'rv' ) or $e = exception error => $msg, rv => HTTP_BAD_REQUEST;

   try {
      my $stash = $self->models->{ $model }->exception_handler( $req, $e );

      $res = $self->views->{ $view }->serialize( $req, $stash )
          or throw error => 'View [_1] returned false', args => [ $view ];
   }
   catch ($render_error) { return __internal_server_error( $e, $render_error ) }

   return $res;
}

# Private functions
sub __internal_server_error {
   my ($e, $secondary_error) = @_; my $message = "${e}\r\n";

   $secondary_error and $message .= "Secondary error: ${secondary_error}";

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
