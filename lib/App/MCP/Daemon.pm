package App::MCP::Daemon;

use App::MCP::Constants    qw( NUL OK TRUE );
use Unexpected::Types      qw( NonEmptySimpleStr NonZeroPositiveInt Object );
use App::MCP::Util         qw( distname terminate );
use Async::IPC::Functions  qw( log_info );
use Class::Usul::Cmd::Util qw( ensure_class_loaded );
use English                qw( -no_match_vars );
use Scalar::Util           qw( blessed );
use Type::Utils            qw( class_type );
use App::MCP::Application;
use App::MCP::DaemonControl;
use Async::IPC;
use IPC::SRLock;
use Plack::Runner;
use Moo;
use Class::Usul::Cmd::Options;

extends 'Class::Usul::Cmd';
with    'App::MCP::Role::Config';
with    'App::MCP::Role::Log';

=pod

=head1 Name

App::MCP::Daemon - Daemon process

=head1 Synopsis

   use App::MCP::Daemon;

=head1 Description

Daemon process

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=item C<port>

The web application server listens on this port for requests. Defaults from the
configuration object

=cut

# Object attributes (public)
# Visible to the command line
option 'port' =>
   is            => 'lazy',
   isa           => NonZeroPositiveInt,
   format        => 'i',
   documentation => 'Port number for the web application server',
   default       => sub { shift->config->port },
   short         => 'p';

=item C<app>

An instance of the L<application|App::MCP::Application> class

=cut

# Ignored by the command line
has 'app' =>
   is      => 'lazy',
   isa     => class_type('App::MCP::Application'),
   default => sub { App::MCP::Application->new(builder => shift) };

=item C<async_factory>

An instance of the L<async factory|Async::IPC> class

An L<async factory|Async::IPC> notifier process

=cut

has 'async_factory' =>
   is      => 'lazy',
   isa     => class_type('Async::IPC'),
   default => sub { Async::IPC->new(builder => shift) },
   handles => ['loop'];

=item C<clock_tick>

An L<async factory|Async::IPC> notifier process

=cut

has 'clock_tick' => is => 'lazy', isa => Object;

=item C<cron>

=cut

has 'cron' => is => 'lazy', isa => Object;

=item C<ip_ev_hndlr>

An L<async factory|Async::IPC> notifier process for the input event handler

=cut

has 'ip_ev_hndlr' => is => 'lazy', isa => Object;

=item C<ipc_ssh>

An L<async factory|Async::IPC> notifier process

=cut

has 'ipc_ssh' => is => 'lazy', isa => Object;

=item C<lock>

An instance of the L<lock|IPC::SRLock> class. Required by the
L<async|Async::IPC> class

=cut

has 'lock' =>
   is      => 'lazy',
   isa     => class_type('IPC::SRLock'),
   default => sub { IPC::SRLock->new(builder => shift) };

=item C<name>

Used for logging by the L<async|Async::IPC> class

=cut

has 'name' =>
   is      => 'lazy',
   isa     => NonEmptySimpleStr,
   default => 'Daemon';

=item C<op_ev_hndlr>

An L<async factory|Async::IPC> notifier process for the output event handler

=cut

has 'op_ev_hndlr' => is => 'lazy', isa => Object;

=item C<server>

An L<async factory|Async::IPC> notifier process for the Web application server

=cut

has 'server' => is => 'lazy', isa => Object;

=back

=head1 Subroutines/Methods

Defines the following methods;

=over 3

=item C<run>

Before the C<run> method in the parent class is called set the C<quiet>
attribute to C<TRUE>

=cut

before 'run' => sub {
   my $self = shift; $self->quiet(TRUE); return;
};

=item C<run_chain>

Decorates the C<run_chain> method in the L<parent|Class::Usul::Cmd> class.
Instantiates an instance of the L<daemon control|App::MCP::DaemonControl> class
and calls it's C<run_command> method

Returns zero upon success non zero otherwise

=cut

around 'run_chain' => sub {
   my ($orig, $self, @args) = @_;

   my $config = $self->config;
   my $name   = lc distname $config->appclass;
   my $rv     = App::MCP::DaemonControl->new({
      name         => blessed $self || $self,
      lsb_start    => '$syslog $remote_fs',
      lsb_stop     => '$syslog',
      lsb_sdesc    => 'Master Control Program',
      lsb_desc     => 'Manages the Master Control Program daemon',
      path         => $config->pathname,

      directory    => $config->appldir,
      program      => sub { shift; $self->_daemon(@_) },
      program_args => [],

      pid_file     => $config->rundir->catfile("${name}.pid"),
      stderr_file  => $self->_stdio_file('err', $name),
      stdout_file  => $self->_stdio_file('out', $name),

      fork         => 2,
      stop_signals => $config->stop_signals,
   })->run_command(@{$self->extra_argv});

   exit defined $rv ? $rv : OK;
};

=item C<pid>

   $pid = pid;

Returns the current process ID

=cut

sub pid {
   return $PID;
}

# Private methods
sub _build_clock_tick {
   my $self = shift;
   my $cron = $self->cron;

   return $self->async_factory->new_notifier(
      type     => 'periodical',
      desc     => 'clock tick handler',
      name     => 'clock',
      code     => sub { $cron->raise },
      interval => $self->config->clock_tick_interval,
   );
}

sub _build_cron {
   my $self       = shift;
   my $app        = $self->app;
   my $daemon_pid = $self->pid;
   my $name       = 'cron';

   return $self->async_factory->new_notifier(
      type    => 'semaphore',
      desc    => 'cron job handler',
      name    => $name,
      on_recv => sub { $app->cron_job_handler($name, $daemon_pid) },
   );
}

sub _build_ip_ev_hndlr {
   my $self       = shift;
   my $app        = $self->app;
   my $daemon_pid = $self->pid;
   my $name       = 'input';

   return $self->async_factory->new_notifier(
      type    => 'semaphore',
      desc    => 'input event handler',
      name    => $name,
      on_recv => sub { $app->input_handler($name, $daemon_pid) },
   );
}

sub _build_ipc_ssh {
   my $self = shift;
   my $app  = $self->app;
   my $name = 'ssh';

   return $self->async_factory->new_notifier(
      type        => 'function',
      desc        => 'SSH remote',
      name        => $name,
      max_calls   => $self->config->max_ssh_worker_calls,
      max_workers => $self->config->max_ssh_workers,
      on_recv     => sub { $app->ipc_ssh_caller($name, @_) },
      on_return   => sub { $app->ipc_ssh_callback($name, @_) },
  );
}

sub _build_op_ev_hndlr {
   my $self       = shift;
   my $app        = $self->app;
   my $daemon_pid = $self->pid;
   my $name       = 'output';
   my $ipc_ssh;

   return $self->async_factory->new_notifier(
      type         => 'semaphore',
      desc         => 'output event handler',
      name         => $name,
      call_ch_mode => 'async',
      before       => sub { $ipc_ssh = $self->ipc_ssh },
      after        => sub { $ipc_ssh->close },
      on_recv      => [
         sub { $app->output_handler($name, $daemon_pid, $ipc_ssh) }
      ],
   );
}

sub _get_server_sub {
   my $self     = shift;
   my $config   = $self->config;
   my $port     = $self->port;
   my $appclass = $config->appclass;
   my $prefix   = lc distname $appclass;
   my $logfile  = "${prefix}-server-${port}.log";
   my $args     = {
      '--port'       => $port,
      '--server'     => $config->server,
      '--access-log' => $config->logsdir->catfile($logfile),
      '--app'        => $config->bin->catfile('mcp-server'),
   };
   my $daemon_pid = $self->pid;
   my $debug      = $self->debug;

   return sub {
      ensure_class_loaded $appclass;
      $appclass->env_var('daemon_pid', $daemon_pid);
      $appclass->env_var('debug', $debug);
      $appclass->env_var('server_port', $port);
      Plack::Runner->run(%{$args});
      return OK;
   };
}

sub _reload {
   my $self = shift;
   my $path = $self->config->pathname;

   $self->run_cmd([ "${path}", 'stop' ]);
   sleep 5;
   $self->run_cmd([ "${path}", '-D', 'start' ]);
   return OK;
}

sub _set_program_name {
   my $self   = shift;
   my $config = $self->config;

   return $PROGRAM_NAME = $config->script . ' - ' . $config->name;
}

sub _stdio_file {
   my ($self, $extn, $name) = @_;

   $name //= lc distname $self->config->appclass;

   return $self->config->tempdir->catfile("${name}.${extn}");
}

sub _build_server {
   my $self = shift;

   return $self->async_factory->new_notifier(
      type => 'process',
      desc => 'web application server',
      name => 'server',
      code => $self->_get_server_sub,
   );
}

sub _hangup_handler { # TODO: Fix this
   my $self = shift;

   $self->run_cmd([ sub { $self->_reload } ], { detach => TRUE });

   return;
}

sub _daemon {
   my $self = shift;
   my $loop = $self->loop;

   $self->_set_program_name;

   log_info $self, 'Starting event loop';

   # Must fork before watching signals
   $self->server;
   $self->op_ev_hndlr;
   $self->ip_ev_hndlr;
   $self->clock_tick;

   $loop->watch_signal( HUP  => sub { $self->_hangup_handler    } );
   $loop->watch_signal( QUIT => sub { terminate $loop           } );
   $loop->watch_signal( TERM => sub { terminate $loop           } );
   $loop->watch_signal( USR1 => sub { $self->ip_ev_hndlr->raise } );
   $loop->watch_signal( USR2 => sub { $self->op_ev_hndlr->raise } );

   log_info $self, 'Event loop started';
   $loop->start; # Loops here until terminate is called
   log_info $self, 'Stopping event loop';

   $self->clock_tick->stop;
   $self->server->stop;
   $self->cron->stop;
   $self->ip_ev_hndlr->stop;
   $self->op_ev_hndlr->stop;
   $loop->watch_child(0);

   log_info $self, 'Event loop stopped';
   exit OK;
}

use namespace::autoclean;

1;

__END__

=back

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<App::MCP::DaemonControl>

=item L<Async::IPC>

=item L<Plack::Runner>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module.  Please report problems to the address
below.  Patches are welcome

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
