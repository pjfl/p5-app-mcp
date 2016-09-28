package App::MCP::Listener;

use namespace::autoclean;

use App::MCP::Constants    qw( NUL TRUE );
use App::MCP::Util         qw( enhance );
use Class::Usul;
use Class::Usul::Types     qw( HashRef Plinth );
use Class::Usul::Functions qw( ensure_class_loaded );
use Plack::Builder;
use Web::Simple;

# Private attributes
has '_config_attr' => is => 'ro',   isa => HashRef, builder => sub { {} },
   init_arg        => 'config';

has '_usul'        => is => 'lazy', isa => Plinth,
   builder         => sub { Class::Usul->new( enhance $_[ 0 ]->_config_attr ) },
   handles         => [ 'config', 'debug', 'dumper', 'l10n', 'lock', 'log' ];

with 'Web::Components::Loader';

# Construction
around 'to_psgi_app' => sub {
   my ($orig, $self, @args) = @_; my $psgi_app = $orig->( $self, @args );

   my $conf   = $self->config; my $static = $conf->serve_as_static;

   my $secret = $conf->salt.$self->models->{root}->get_connect_info->[ 2 ];

   builder {
      mount $conf->mount_point => builder {
         enable 'ContentLength';
         enable 'FixMissingBodyInRedirect';
         enable "ConditionalGET";
         enable 'Deflater',
            content_type => $conf->deflate_types, vary_user_agent => TRUE;
         enable 'Static',
            path => qr{ \A / (?: $static ) }mx, root => $conf->root;
         # TODO: Need to add domain from the request which we dont have yet
         enable 'Session::Cookie',
            expires     => 7_776_000,
            httponly    => TRUE,
            path        => $conf->mount_point,
            secret      => $secret,
            session_key => 'mcp_session';
         enable "LogDispatch", logger => $self->log;
         enable_if { $self->debug } 'Debug';
         $psgi_app;
      };
   };
};

sub BUILD {
   my $self     = shift;
   my $server   = ucfirst( $ENV{PLACK_ENV} // NUL );
   my $appclass = $self->config->appclass; ensure_class_loaded $appclass;
   my $port     = $appclass->env_var( 'PORT' );
   my $info     = 'v'.$appclass->VERSION; $port and $info .= " on port ${port}";

   $self->log->info( "${server} Server started ${info}" );

   return;
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
