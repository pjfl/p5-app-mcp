package App::MCP::Daemon;

use namespace::autoclean;

use App::MCP;
use App::MCP::Application;
use App::MCP::Constants   qw( LANG NUL OK TRUE );
use App::MCP::DaemonControl;
use App::MCP::Functions   qw( env_var terminate );
use Async::IPC;
use Async::IPC::Functions qw( log_info );
use Class::Usul::Types    qw( NonEmptySimpleStr NonZeroPositiveInt Object );
use English               qw( -no_match_vars );
use Plack::Runner;
use Scalar::Util          qw( blessed );
use Moo;
use Class::Usul::Options;

extends q(Class::Usul::Programs);

# Private methods
my $_build_clock_tick = sub {
   my $self = shift; my $cron = $self->cron;

   return $self->async_factory->new_notifier
      (  type     => 'periodical',
         desc     => 'clock tick handler',
         name     => 'clock',
         code     => sub { $cron->raise },
         interval => $self->config->clock_tick_interval, );
};

my $_build_cron = sub {
   my $self = shift; my $app = $self->app;

   my $daemon_pid = $self->pid; my $name = 'cron';

   return $self->async_factory->new_notifier
      (  type    => 'semaphore',
         desc    => 'cron job handler',
         name    => $name,
         on_recv => sub { $app->cron_job_handler( $name, $daemon_pid ) }, );
};

my $_build_ip_ev_hndlr = sub {
   my $self = shift; my $app = $self->app;

   my $daemon_pid = $self->pid; my $name = 'input';

   return $self->async_factory->new_notifier
      (  type    => 'semaphore',
         desc    => 'input event handler',
         name    => $name,
         on_recv => sub { $app->input_handler( $name, $daemon_pid ) }, );
};

my $_build_ipc_ssh = sub {
   my $self = shift; my $app = $self->app; my $name = 'ssh';

   return $self->async_factory->new_notifier
      (  type        => 'function',
         desc        => 'SSH remote',
         name        => $name,
         max_calls   => $self->config->max_ssh_worker_calls,
         max_workers => $self->config->max_ssh_workers,
         on_recv     => sub { $app->ipc_ssh_caller( $name, @_ ) },
         on_return   => sub { $app->ipc_ssh_callback( $name, @_ ) }, );
};

my $_build_op_ev_hndlr = sub {
   my $self = shift; my $app = $self->app; my $name = 'output'; my $ipc_ssh;

   return $self->async_factory->new_notifier
      (  type         => 'semaphore',
         desc         => 'output event handler',
         name         => $name,
         call_ch_mode => 'async',
         before       =>   sub { $ipc_ssh = $self->ipc_ssh },
         on_recv      => [ sub { $app->output_handler( $name, $ipc_ssh ) }, ],
         after        =>   sub { $ipc_ssh->close }, );
};

my $_get_listener_sub = sub {
   my $self = shift; my $conf = $self->config; my $port = $self->port;

   my $args = {
      '--port'       => $port,
      '--server'     => $conf->server,
      '--access-log' => $conf->logsdir->catfile( 'listener-access.log' ),
      '--app'        => $conf->binsdir->catfile( 'mcp-listener' ), };

   my $daemon_pid = $self->pid; my $debug = $self->debug;

   return sub {
      env_var 'DAEMON_PID',    $daemon_pid;
      env_var 'DEBUG',         $debug;
      env_var 'LISTENER_PORT', $port;
      Plack::Runner->run( %{ $args } );
      return OK;
   };
};

my $_reload = sub {
   my $self = shift; my $path = $self->config->pathname;

   $self->run_cmd( [ "${path}", 'stop' ] );
   sleep 5;
   $self->run_cmd( [ "${path}", '-D', 'start' ] );
   return OK;
};

my $_set_program_name = sub { # Localisation triggers cache file creation
   my $self = shift; my $name = $self->l10n->localizer( LANG, 'master' );

   return $PROGRAM_NAME = $self->config->pathname." - ${name}";
};

my $_stdio_file = sub {
   my ($self, $extn, $name) = @_; $name ||= $self->config->name;

   return $self->file->tempdir->catfile( "${name}.${extn}" );
};

my $_build_listener = sub {
   my $self = shift;

   return $self->async_factory->new_notifier
      (  type => 'process',
         desc => 'web application server',
         name => 'listen',
         code => $self->$_get_listener_sub, );
};

my $_hangup_handler = sub { # TODO: Fix this
   my $self = shift;

   $self->run_cmd( [ sub { $self->$_reload } ], { detach => TRUE } );

   return;
};

my $_daemon = sub {
   my $self = shift; my $loop = $self->loop; $self->$_set_program_name;

   log_info $self, 'Starting event loop';

   # Must fork before watching signals
   $self->listener; $self->op_ev_hndlr; $self->ip_ev_hndlr; $self->clock_tick;

   $loop->watch_signal( HUP  => sub { $self->$_hangup_handler   } );
   $loop->watch_signal( QUIT => sub { terminate $loop           } );
   $loop->watch_signal( TERM => sub { terminate $loop           } );
   $loop->watch_signal( USR1 => sub { $self->ip_ev_hndlr->raise } );
   $loop->watch_signal( USR2 => sub { $self->op_ev_hndlr->raise } );

   log_info $self, 'Event loop started';
   $loop->start; # Loops here until terminate is called
   log_info $self, 'Stopping event loop';

   $self->clock_tick->stop;
   $self->listener->stop;
   $self->cron->stop;
   $self->ip_ev_hndlr->stop;
   $self->op_ev_hndlr->stop;
   $loop->watch_child( 0 );

   log_info $self, 'Event loop stopped';
   exit OK;
};

# Override defaults in parent class
has '+config_class' => default => 'App::MCP::Config';

# Object attributes (public)
#   Visible to the command line
option 'port'       => is => 'lazy', isa => NonZeroPositiveInt,
   documentation    => 'Port number for the input event listener',
   builder          => sub { $_[ 0 ]->config->port }, format => 'i',
   short            => 'p';

#   Ingnored by the command line
has 'app'           => is => 'lazy', isa => Object, builder => sub {
   App::MCP::Application->new( builder => $_[ 0 ], port => $_[ 0 ]->port ) };

has 'async_factory' => is => 'lazy', isa => Object, builder => sub {
   Async::IPC->new( builder => $_[ 0 ] ) }, handles => [ 'loop' ];

has 'clock_tick'    => is => 'lazy', isa => Object,
   builder          => $_build_clock_tick;

has 'cron'          => is => 'lazy', isa => Object,
   builder          => $_build_cron;

has 'ip_ev_hndlr'   => is => 'lazy', isa => Object,
   builder          => $_build_ip_ev_hndlr;

has 'ipc_ssh'       => is => 'lazy', isa => Object,
   builder          => $_build_ipc_ssh;

has 'listener'      => is => 'lazy', isa => Object,
   builder          => $_build_listener;

has 'name'          => is => 'lazy', isa => NonEmptySimpleStr,
   builder          => sub { $_[ 0 ]->config->log_key };

has 'op_ev_hndlr'   => is => 'lazy', isa => Object,
   builder          => $_build_op_ev_hndlr;

# Construction
before 'run' => sub {
   my $self = shift; $self->quiet( TRUE ); return;
};

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
      program      => sub { shift; $self->$_daemon( @_ ) },
      program_args => [],

      pid_file     => $conf->rundir->catfile( "${name}.pid" ),
      stderr_file  => $self->$_stdio_file( 'err' ),
      stdout_file  => $self->$_stdio_file( 'out' ),

      fork         => 2,
      stop_signals => $conf->stop_signals,
   } )->run;

   exit defined $rv ? $rv : OK;
};

# Public methods
sub pid {
   return $PID;
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
