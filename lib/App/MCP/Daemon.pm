package App::MCP::Daemon;

use namespace::autoclean;

use Moo;
use App::MCP;
use App::MCP::Application;
use App::MCP::Async;
use App::MCP::Constants qw( NUL OK TRUE );
use App::MCP::DaemonControl;
use App::MCP::Functions qw( env_var log_leader terminate );
use Class::Usul::Options;
use Class::Usul::Types  qw( NonZeroPositiveInt Object );
use English             qw( -no_match_vars );
use Plack::Runner;
use Scalar::Util        qw( blessed );

extends q(Class::Usul::Programs);

# Override defaults in parent class
has '+config_class' => default => 'App::MCP::Config';

# Object attributes (public)
#   Visible to the command line
option 'port'       => is => 'ro',   isa => NonZeroPositiveInt,
   documentation    => 'Port number for the input event listener',
   default          => sub { $_[ 0 ]->config->port }, format => 'i';

#   Ingnored by the command line
has 'app'           => is => 'lazy', isa => Object, builder => sub {
   App::MCP::Application->new( builder => $_[ 0 ], port => $_[ 0 ]->port ) };

has 'async_factory' => is => 'lazy', isa => Object, builder => sub {
   App::MCP::Async->new( builder => $_[ 0 ] ) }, handles => [ qw( loop ) ];

has 'clock_tick'    => is => 'lazy', isa => Object;

has 'cron'          => is => 'lazy', isa => Object;

has 'ip_ev_hndlr'   => is => 'lazy', isa => Object;

has 'ipc_ssh'       => is => 'lazy', isa => Object;

has 'listener'      => is => 'lazy', isa => Object;

has 'op_ev_hndlr'   => is => 'lazy', isa => Object;

# Construction
around 'run_chain' => sub {
   my ($orig, $self, @args) = @_; @ARGV = @{ $self->extra_argv };

   my $conf = $self->config; my $name = $conf->name;

   my $rv   = App::MCP::DaemonControl->new( {
      name         => blessed $self || $self,
      lsb_start    => '$syslog $remote_fs',
      lsb_stop     => '$syslog',
      lsb_sdesc    => 'Master Control Program',
      lsb_desc     => 'Manages the Master Control Program daemon',
      path         => $conf->pathname,

      directory    => $conf->appldir,
      program      => sub { shift; $self->master_daemon( @_ ) },
      program_args => [],

      pid_file     => $conf->rundir->catfile( "${name}.pid" ),
      stderr_file  => $self->_stdio_file( 'err' ),
      stdout_file  => $self->_stdio_file( 'out' ),

      fork         => 2,
      stop_signals => $conf->stop_signals,
   } )->run;

   exit defined $rv ? $rv : OK;
};

before 'run' => sub {
   my $self = shift; $self->quiet( TRUE ); return;
};

# Public methods
sub master_daemon {
   my $self = shift;
   my $loop = $self->loop; $self->_set_program_name;
   my $lead = log_leader 'info', $self->config->log_key;
   my $log  = $self->log; $log->info( "${lead}Starting event loop" );

   $self->listener; $self->op_ev_hndlr; $self->ip_ev_hndlr; $self->clock_tick;

   $loop->watch_signal( HUP  => sub { $self->_hangup_handler   } );
   $loop->watch_signal( QUIT => sub { terminate $loop          } );
   $loop->watch_signal( TERM => sub { terminate $loop          } );
   $loop->watch_signal( USR1 => sub { $self->ip_ev_hndlr->call } );
   $loop->watch_signal( USR2 => sub { $self->op_ev_hndlr->call } );

   $log->info( $lead.'Event loop started' );
   $loop->start; # Loops here until terminate is called
   $log->info( $lead.'Stopping event loop' );

   $self->cron->stop;
   $self->ipc_ssh->stop;
   $self->listener->stop;
   $self->clock_tick->stop;
   $self->ip_ev_hndlr->stop;
   $self->op_ev_hndlr->stop;
   $loop->watch_child( 0 );

   $log->info( $lead.'Event loop stopped' );
   exit OK;
}

# Private methods
sub _build_clock_tick {
   my $self = shift; my $cron = $self->cron;

   return $self->async_factory->new_notifier
      (  code     => sub { $cron->call },
         interval => $self->config->clock_tick_interval,
         desc     => 'clock tick handler',
         key      => 'CLOCK',
         type     => 'periodical' );
}

sub _build_cron {
   my $self = shift; my $app = $self->app;

   my $daemon_pid = $PID; my $log_key = 'CRON';

   return $self->async_factory->new_notifier
      (  code => sub { $app->cron_job_handler( $log_key, $daemon_pid ) },
         desc => 'cron job handler',
         key  => $log_key,
         type => 'routine' );
}

sub _build_ip_ev_hndlr {
   my $self = shift; my $app = $self->app;

   my $daemon_pid = $PID; my $log_key = 'INPUT';

   return $self->async_factory->new_notifier
      (  code => sub { $app->input_handler( $log_key, $daemon_pid ) },
         desc => 'input event handler',
         key  => $log_key,
         type => 'routine' );
}

sub _build_ipc_ssh {
   my $self = shift; my $app = $self->app;

   my $conf = $self->config; my $log_key = 'IPCSSH';

   return $self->async_factory->new_notifier
      (  channels    => 'io',
         code        => sub { $app->ipc_ssh_caller( $log_key, @_ ) },
         desc        => 'ipcssh',
         key         => $log_key,
         max_calls   => $conf->max_ssh_worker_calls,
         max_workers => $conf->max_ssh_workers,
         type        => 'function' );
}

sub _build_listener {
   my $self = shift;

   return $self->async_factory->new_notifier
      (  code => $self->_get_listener_sub,
         desc => 'listener',
         key  => 'LISTEN',
         type => 'process' );
}

sub _build_op_ev_hndlr {
   my $self = shift; my $app = $self->app;

   my $ipc_ssh = $self->ipc_ssh; my $log_key = 'OUTPUT';

   return $self->async_factory->new_notifier
      (  before => sub { $app->ipc_ssh_install_callback( $log_key, $ipc_ssh ) },
         code   => sub { $app->output_handler( $log_key, $ipc_ssh ) },
         desc   => 'output event handler',
         key    => $log_key,
         type   => 'routine' );
}

sub _get_listener_sub {
   my $self = shift; my $conf = $self->config;

   my $args = {
      '--port'       => $self->port,
      '--server'     => $conf->server,
      '--access-log' => $conf->logsdir->catfile( 'listener-access.log' ),
      '--app'        => $conf->binsdir->catfile( 'mcp-listener' ), };

   my $daemon_pid = $PID; my $debug = $self->debug; my $port = $self->port;

   return sub {
      env_var 'DAEMON_PID',    $daemon_pid;
      env_var 'DEBUG',         $debug;
      env_var 'LISTENER_PORT', $port;
      Plack::Runner->run( %{ $args } );
      return OK;
   };
}

sub _hangup_handler { # TODO: On reload - stop, Class::Unload; require; start
}

sub _set_program_name {
   $PROGRAM_NAME = $_[ 0 ]->config->pathname.' master'; return;
}

sub _stdio_file {
   my ($self, $extn, $name) = @_; $name ||= $self->config->name;

   return $self->file->tempdir->catfile( "${name}.${extn}" );
}

1;

__END__

=pod

=head1 Name

App::MCP::Daemon - <One-line description of module's purpose>

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

=item L<Class::Usul>

=item L<File::DataClass>

=item L<Plack::Runner>

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
