# @(#)$Ident: Daemon.pm 2013-05-31 20:51 pjf ;

package App::MCP::Daemon;

use version; our $VERSION = qv( sprintf '0.2.%d', q$Rev: 15 $ =~ /\d+/gmx );

use App::MCP;
use App::MCP::Async;
use App::MCP::DaemonControl;
use App::MCP::Functions          qw(log_leader);
use Class::Usul::Constants;
use Class::Usul::Moose;
use English                      qw(-no_match_vars);
use File::DataClass::Constraints qw(File Path);
use Plack::Runner;

extends q(Class::Usul::Programs);

# Override defaults in parent class
has '+config_class'  => default => 'App::MCP::Config';

# Object attributes (public)
#   Visible to the command line
has 'database'       => is => 'ro',   isa => NonEmptySimpleStr,
   documentation     => 'The database to connect to',
   default           => sub { $_[ 0 ]->config->database };

has 'identity_file'  => is => 'lazy', isa => File, coerce => TRUE,
   documentation     => 'Path to private SSH key',
   default           => sub { $_[ 0 ]->config->identity_file };

has 'port'           => is => 'ro',   isa => PositiveInt,
   documentation     => 'Port number for the input event listener',
   default           => sub { $_[ 0 ]->config->port };

#   Ingnored by the command line
has '_app'           => is => 'lazy', isa => Object, reader => 'app';

has '_async_factory' => is => 'lazy', isa => Object,
   handles           => [ qw(loop) ], reader => 'async_factory';

has '_clock_tick'    => is => 'lazy', isa => Object, reader => 'clock_tick';

has '_cron'          => is => 'lazy', isa => Object, reader => 'cron';

has '_ip_ev_hndlr'   => is => 'lazy', isa => Object, reader => 'ip_ev_hndlr';

has '_ipc_ssh'       => is => 'lazy', isa => Object, reader => 'ipc_ssh';

has '_listener'      => is => 'lazy', isa => Object, reader => 'listener';

has '_op_ev_hndlr'   => is => 'lazy', isa => Object, reader => 'op_ev_hndlr';

# Construction
around 'run' => sub {
   my ($next, $self, @args) = @_; $self->quiet( TRUE );

   return $self->$next( @args );
};

around 'run_chain' => sub {
   my ($next, $self, @args) = @_; @ARGV = @{ $self->extra_argv };

   my $config = $self->config; my $name = $config->name;

   App::MCP::DaemonControl->new( {
      name         => blessed $self || $self,
      lsb_start    => '$syslog $remote_fs',
      lsb_stop     => '$syslog',
      lsb_sdesc    => 'Master Control Program',
      lsb_desc     => 'Manages the Master Control Program daemon',
      path         => $config->pathname,

      directory    => $config->appldir,
      program      => sub { shift; $self->daemon( @_ ) },
      program_args => [],

      pid_file     => $config->rundir->catfile( "${name}.pid" ),
      stderr_file  => $self->_stdio_file( 'err' ),
      stdout_file  => $self->_stdio_file( 'out' ),

      fork         => 2,
      stop_signals => $config->stop_signals,
   } )->run;

   return $self->$next( @args ); # Never reached
};

# Public methods
sub daemon {
   my $self = shift; my $log = $self->log; my $loop = $self->loop;

   my $lead = log_leader 'info', $self->config->log_key;

   $log->info( $lead.'Starting event loop' ); $self->_set_program_name;

   $self->op_ev_hndlr; $self->ip_ev_hndlr; $self->listener; $self->clock_tick;

   $loop->attach_signal( HUP  => sub { $self->_hangup_handler      } );
   $loop->attach_signal( QUIT => sub { __terminate( $loop )        } );
   $loop->attach_signal( TERM => sub { __terminate( $loop )        } );
   $loop->attach_signal( USR1 => sub { $self->ip_ev_hndlr->trigger } );
   $loop->attach_signal( USR2 => sub { $self->op_ev_hndlr->trigger } );

   $log->info( $lead.'Event loop started' );
   $loop->start; # Blocks here until __terminate is called
   $log->info( $lead.'Stopping event loop' );

   $self->clock_tick->stop;
   $self->cron->stop;
   $self->listener->stop;
   $self->ip_ev_hndlr->stop;
   $self->op_ev_hndlr->stop;
   $loop->watch_child( 0 );

   $log->info( $lead.'Event loop stopped' );
   exit OK;
}

# Private methods
sub _build__app {
   return App::MCP->new( builder => $_[ 0 ] );
}

sub _build__async_factory {
   return App::MCP::Async->new( builder => $_[ 0 ] );
}

sub _build__clock_tick {
   my $self = shift; my $app = $self->app;

   my $cron = $self->cron; my $key = $self->config->log_key;

   return $self->async_factory->new_notifier
      (  code     => sub { $app->clock_tick_handler( $key, $cron ) },
         interval => $self->config->clock_tick_interval,
         desc     => 'clock tick handler',
         key      => 'CLOCK',
         type     => 'periodical' );
}

sub _build__cron {
   my $self = shift; my $app = $self->app; my $daemon_pid = $PID;

   return $self->async_factory->new_notifier
      (  code => sub { $app->cron_job_handler( $daemon_pid ) },
         desc => 'cron job handler',
         key  => 'CRON',
         type => 'routine' );
}

sub _build__ip_ev_hndlr {
   my $self = shift; my $app = $self->app; my $daemon_pid = $PID;

   return $self->async_factory->new_notifier
      (  code => sub { $app->input_handler( $daemon_pid ) },
         desc => 'input event handler',
         key  => 'INPUT',
         type => 'routine' );
}

sub _build__ipc_ssh {
   my $self = shift; my $app = $self->app;

   return $self->async_factory->new_notifier
      (  code        => sub { $app->ipc_ssh_handler( @_ ) },
         desc        => 'ipcssh',
         key         => 'IPCSSH',
         max_calls   => $self->config->max_ssh_worker_calls,
         max_workers => $self->config->max_ssh_workers,
         type        => 'function' );
}

sub _build__listener {
   my $self = shift; my $daemon_pid = $PID;

   return $self->async_factory->new_notifier
      (  code => sub {
            $ENV{MCP_DAEMON_PID} = $daemon_pid;
            Plack::Runner->run( $self->_get_listener_args );
            return OK;
         },
         desc => 'listener',
         key  => 'LISTEN',
         type => 'process' );
}

sub _build__op_ev_hndlr {
   my $self = shift; my $app = $self->app; my $ipc_ssh = $self->ipc_ssh;

   return $self->async_factory->new_notifier
      (  after => sub { $ipc_ssh->stop },
         code  => sub { $app->output_handler( $ipc_ssh ) },
         desc  => 'output event handler',
         key   => 'OUTPUT',
         type  => 'routine' );
}

sub _get_listener_args {
   my $self   = shift;
   my $config = $self->config;
   my $args   = {
      '--port'       => $self->port,
      '--server'     => $config->server,
      '--access-log' => $config->logsdir->catfile( 'listener.log' ),
      '--app'        => $config->binsdir->catfile( 'mcp-listener' ), };

   return %{ $args };
}

sub _hangup_handler { # TODO: What should we do on reload?
}

sub _set_program_name {
   my $self = shift;
   my $cfg  = $self->config;
   my $key  = ucfirst lc $cfg->log_key;

   $PROGRAM_NAME = $cfg->appclass."::${key} ".$cfg->pathname;
   return;
}

sub _stdio_file {
   my ($self, $extn, $name) = @_; $name ||= $self->config->name;

   return $self->file->tempdir->catfile( "${name}.${extn}" );
}

# Private functions
sub __terminate {
   my $loop = shift;

   $loop->detach_signal( 'QUIT' ); $loop->detach_signal( 'TERM' ); $loop->stop;

   return;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=head1 Name

App::MCP::Daemon - <One-line description of module's purpose>

=head1 Version

This documents version v0.2.$Rev: 15 $

=head1 Synopsis

   use App::MCP::Daemon;
   # Brief but working code examples

=head1 Description

=head1 Configuration and Environment

=head1 Subroutines/Methods

=head2 daemon

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<App::MCP::Async>

=item L<App::MCP::DaemonControl>

=item L<CatalystX::Usul::TraitFor::ConnectInfo>

=item L<Class::Usul>

=item L<File::DataClass>

=item L<IPC::PerlSSH>

=item L<Plack::Runner>

=item L<TryCatch>

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
