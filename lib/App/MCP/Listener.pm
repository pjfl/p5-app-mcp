package App::MCP::Listener;

use App::MCP::Constants     qw( FALSE NUL TRUE );
use HTTP::Status            qw( HTTP_FOUND );
use Class::Usul::Cmd::Types qw( Bool );
use Class::Usul::Cmd::Util  qw( ensure_class_loaded );
use Plack::Builder;
use Web::Simple;

with 'App::MCP::Role::Config';
with 'App::MCP::Role::Log';
with 'App::MCP::Role::Session';
with 'Web::Components::Loader';

=pod

=head1 Name

App::MCP::Listener - Web application server

=head1 Synopsis

   use App::MCP::Listener;

=head1 Description

Web application server

=head1 Configuration and Environment

Defines the following attributes;

=item C<debug>

Set from the application class environment debug variable

=cut

has 'debug' =>
   is      => 'lazy',
   ia      => Bool,
   default => sub { shift->config->appclass->env_var('debug') ? TRUE : FALSE };

=head1 Subroutines/Methods

Defines the following methods;

=over 3

=item C<to_psgi_app>

Called by L<Plack::Runner>. The web server

=cut

around 'to_psgi_app' => sub {
   my ($orig, $self, @args) = @_;

   my $psgi_app = $orig->($self, @args);
   my $config   = $self->config;
   my $static   = $config->static;

   builder {
      enable 'ConditionalGET';
      enable 'Options', allowed => [ qw( DELETE GET POST PUT HEAD ) ];
      enable 'Head';
      enable 'ContentLength';
      enable 'FixMissingBodyInRedirect';
      enable 'Deflater',
         content_type    => $config->deflate_types,
         vary_user_agent => TRUE;
      mount $config->mount_point => builder {
         enable 'Static',
            path => qr{ \A / (?: $static) / }mx,
            root => $config->rootdir;
         enable 'Session', $self->session->middleware_config;
         enable 'LogDispatch', logger => $self->log;
         $psgi_app;
      };
      mount '/' => builder {
         sub { [ HTTP_FOUND, [ 'Location' => $config->default_route ], [] ] }
      };
   };
};

=item C<BUILD>

Logs that the server has started

=cut

sub BUILD {
   my $self  = shift;
   my $class = $self->config->appclass;

   ensure_class_loaded $class;

   my $server = ucfirst($ENV{PLACK_ENV} // NUL);
   my $debug  = $self->debug ? 'on' : 'off';
   my $port   = $class->env_var('server_port') // 5_000;
   my $info   = 'v' . $class->VERSION . " port ${port} debug ${debug}";

   $self->log->info("WebServer: Started ${class} ${server} ${info}");
   return;
}

# Private
sub _build__factory {
   my $self = shift;

   return Web::ComposableRequest->new(
      buildargs => $self->factory_args,
      config    => $self->config->request,
   );
}

use namespace::autoclean;

1;

__END__

=back

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<App::MCP::Role::Config>

=item L<App::MCP::Role::Log>

=item L<App::MCP::Role::Session>

=item L<Plack::Builder>

=item L<Web::Components::Loader>

=item L<Web::Simple>

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

Peter Flanigan, C<< <pjfl@cpan.org> >>

=head1 License and Copyright

Copyright (c) 2025 Peter Flanigan. All rights reserved

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
