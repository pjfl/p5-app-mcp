package App::MCP::Listener;

use namespace::autoclean;

use App::MCP;
use App::MCP::Constants    qw( EXCEPTION_CLASS FALSE NUL TRUE );
use App::MCP::Functions    qw( env_var );
use Class::Usul;
use Class::Usul::Functions qw( find_apphome get_cfgfiles throw );
use Class::Usul::Types     qw( BaseType );
use Plack::Builder;
use Unexpected::Functions  qw( Unspecified );
use Web::Simple;

# Attribute construction
my $_build_usul = sub {
   my $self = shift;
   my $attr = { config => $self->config, debug => env_var( 'DEBUG' ) // FALSE };
   my $conf = $attr->{config};

   $conf->{appclass    } or  throw Unspecified, [ 'application class' ];
   $attr->{config_class} //= $conf->{appclass}.'::Config';
   $conf->{name        } //= 'listener';
   $conf->{home        }   = find_apphome $conf->{appclass};
   $conf->{cfgfiles    }   = get_cfgfiles $conf->{appclass}, $conf->{home};

   return Class::Usul->new( $attr );
};

# Public attributes
has 'usul' => is => 'lazy', isa => BaseType, builder => $_build_usul,
   handles => [ 'log' ];

with q(App::MCP::Role::ComponentLoading);

# Construction
around 'to_psgi_app' => sub {
   my ($orig, $self, @args) = @_; my $app = $orig->( $self, @args );

   my $conf   = $self->usul->config;
   my $point  = $conf->mount_point;
   my $secret = $conf->salt.$self->models->{root}->get_connect_info->[ 2 ];
   my $static = $conf->serve_as_static;

   builder {
      mount "${point}" => builder {
         enable "ConditionalGET";
         enable 'Deflater',
            content_type => $conf->deflate_types, vary_user_agent => TRUE;
         enable 'Static',
            path => qr{ \A / (?: $static ) }mx, root => $conf->root;
         # TODO: Need to add domain from the request which we dont have yet
         enable 'Session::Cookie',
            expires     => 7_776_000, httponly => TRUE,
            path        => $point,    secret   => $secret,
            session_key => 'mcp_session';
         enable "LogDispatch", logger => $self->usul->log;
         enable_if { $self->usul->debug } 'Debug';
         $app;
      };
   };
};

sub BUILD {
   my $self   = shift;
   my $server = ucfirst( $ENV{ 'PLACK_ENV' } // NUL );
   my $port   = env_var 'LISTENER_PORT';
      $port   = $port ? " on port ${port}" : NUL;
   my $ver    = $App::MCP::VERSION;

   $self->log->info( "${server} Server started v${ver}${port}" );
   return;
}

# Public methods
sub dispatch_request {
   my $f = sub () { my $self = shift; response_filter { $self->render( @_ ) } };

   return $f, map { $_->dispatch_request } @{ $_[ 0 ]->controllers };
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
