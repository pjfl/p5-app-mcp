package App::MCP::Listener;

use App::MCP::Constants    qw( FALSE NUL TRUE );
use HTTP::Status           qw( HTTP_FOUND );
use Class::Usul::Cmd::Util qw( ensure_class_loaded );

use Plack::Builder;
use Web::Simple;

with 'App::MCP::Role::Config';
with 'App::MCP::Role::Log';
with 'App::MCP::Role::Session';
with 'Web::Components::Loader';

# Construction
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
            root => $config->root;
         enable 'Session', $self->session->middleware_config;
         enable 'LogDispatch', logger => $self->log;
         $psgi_app;
      };
      mount '/' => builder {
         sub { [ HTTP_FOUND, [ 'Location', $config->default_route ], [] ] }
      };
   };
};

sub BUILD {
   my $self   = shift;
   my $class  = $self->config->appclass;
   my $server = ucfirst($ENV{PLACK_ENV} // NUL);
   my $port   = $class->env_var('port') // 5_000;

   ensure_class_loaded $class;

   my $info   = 'v' . $class->VERSION . " started on port ${port}";

   $self->log->info("HTTPServer: ${class} ${server} ${info}");
   return;
}

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

Copyright (c) 2015 Peter Flanigan. All rights reserved

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
