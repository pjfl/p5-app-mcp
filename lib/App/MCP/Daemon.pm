# @(#)$Ident: Daemon.pm 2013-05-28 21:16 pjf ;

package App::MCP::Daemon;

use version; our $VERSION = qv( sprintf '0.2.%d', q$Rev: 7 $ =~ /\d+/gmx );

use Class::Usul::Moose;
use Class::Usul::Constants;
use Class::Usul::Functions       qw(create_token bson64id);
use App::MCP::Async;
use App::MCP::DaemonControl;
use App::MCP::Functions          qw(pad5z);
use English                      qw(-no_match_vars);
use File::DataClass::Constraints qw(File Path);
use IPC::PerlSSH;
use Plack::Runner;
use TryCatch;

extends q(Class::Usul::Programs);
with    q(CatalystX::Usul::TraitFor::ConnectInfo);

# Override defaults in base class
has '+config_class'   => default => 'App::MCP::Config';

# Object attributes (public)
#   Visible to the command line
has 'autotrigger'     => is => 'ro',   isa => Bool,
   documentation      => 'Trigger output event handler with each clock tick',
   default            => FALSE;

has 'database'        => is => 'ro',   isa => NonEmptySimpleStr,
   documentation      => 'The database to connect to',
   default            => sub { $_[ 0 ]->config->database };

has 'identity_file'   => is => 'lazy', isa => File, coerce => TRUE,
   documentation      => 'Path to private SSH key',
   default            => sub { $_[ 0 ]->config->identity_file };

has 'max_ssh_workers' => is => 'ro',   isa => PositiveInt,
   documentation      => 'Maximum number of SSH worker processes',
   default            => sub { $_[ 0 ]->config->max_ssh_workers };

has 'port'            => is => 'ro',   isa => PositiveInt,
   documentation      => 'Port number for the input event listener',
   default            => sub { $_[ 0 ]->config->port };

has 'schema_class'    => is => 'lazy', isa => LoadableClass, coerce => TRUE,
   documentation      => 'Classname of the schema to load',
   default            => sub { $_[ 0 ]->config->schema_class };

has 'server'          => is => 'ro',   isa => NonEmptySimpleStr,
   documentation      => 'Plack server class used for the event listener',
   default            => sub { $_[ 0 ]->config->server };

#   Ingnored by the command line
has '_async_factory'  => is => 'lazy', isa => Object, reader => 'async_factory';

has '_clock_tick'     => is => 'lazy', isa => Object, reader => 'clock_tick';

has '_interval'       => is => 'lazy', isa => PositiveInt,
   default            => sub { $_[ 0 ]->config->clock_tick_interval },
   reader             => 'interval';

has '_ip_ev_hndlr'    => is => 'lazy', isa => Object, reader => 'ip_ev_hndlr';

has '_ipc_ssh'        => is => 'lazy', isa => Object, reader => 'ipc_ssh';

has '_library_class'  => is => 'ro',   isa => NonEmptySimpleStr,
   default            => 'App::MCP::SSHLibrary', reader => 'library_class';

has '_listener'       => is => 'lazy', isa => Object, reader => 'listener';

has '_loop'           => is => 'lazy', isa => Object,
   default            => sub { $_[ 0 ]->async_factory->loop }, reader => 'loop';

has '_op_ev_hndlr'    => is => 'lazy', isa => Object, reader => 'op_ev_hndlr';

has '_schema'         => is => 'lazy', isa => Object, reader => 'schema';

has '_servers'        => is => 'lazy', isa => ArrayRef, auto_deref => TRUE,
   default            => sub { $_[ 0 ]->config->servers }, reader => 'servers';

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

   my $stop = sub { $loop->detach_signal( 'TERM' ); $loop->stop };

   my $did  = pad5z(); $log->info( "DAEMON[${did}]: Starting event loop" );

   $self->op_ev_hndlr; $self->ip_ev_hndlr; $self->listener; $self->clock_tick;

   $loop->attach_signal( TERM => $stop );
   $loop->attach_signal( USR1 => sub { $self->ip_ev_hndlr->trigger } );
   $loop->attach_signal( USR2 => sub { $self->op_ev_hndlr->trigger } );
   $loop->attach_signal( HUP  => sub { $self->_hangup_handler      } );
   $loop->run; # Blocks here until loop stop is called
   $log->info( "DAEMON[${did}]: Stopping event loop" );
   $self->clock_tick->stop;
   $self->listener->stop;
   $self->ip_ev_hndlr->stop;
   $self->op_ev_hndlr->stop;
   $loop->watch_child( 0 );
   $log->info( "DAEMON[${did}]: Event loop stopped" );
   exit OK;
}

# Private methods
sub _build__async_factory {
   return App::MCP::Async->new( builder => $_[ 0 ] );
}

sub _build__clock_tick {
   my $self = shift; my $daemon_pid = $PID;

   return $self->async_factory->new_notifier
      (  code     => sub { $self->_clock_tick_handler( $daemon_pid, @_ ) },
         interval => $self->interval,
         desc     => 'clock tick handler',
         key      => ' CLOCK',
         type     => 'periodical' );
}

sub _build__ip_ev_hndlr {
   my $self = shift; my $daemon_pid = $PID;

   return $self->async_factory->new_notifier
      (  code => sub { $self->_input_handler( $daemon_pid, @_ ) },
         desc => 'input event handler',
         key  => ' INPUT',
         type => 'routine' );
}

sub _build__ipc_ssh {
   my $self = shift;

   return $self->async_factory->new_notifier
      (  code        => sub { $self->_ipc_ssh_handler( @_ ) },
         desc        => 'ipcssh worker',
         key         => 'IPCSSH',
         max_calls   => $self->config->max_ssh_worker_calls,
         max_workers => $self->max_ssh_workers,
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
   my $self = shift; my $ipc_ssh = $self->ipc_ssh;

   return $self->async_factory->new_notifier
      (  code => sub {
            $self->_output_handler( $ipc_ssh, @_ ); $ipc_ssh->stop;
         },
         desc => 'output event handler',
         key  => 'OUTPUT',
         type => 'routine' );
}

sub _build__schema {
   my $self = shift;
   my $info = $self->get_connect_info( $self, { database => $self->database } );

   my $params = { quote_names => TRUE }; # TODO: Fix me

   return $self->schema_class->connect( @{ $info }, $params );
}

sub _clock_tick_handler {
   my ($self, $daemon_pid) = @_;

   $self->lock->set( k => 'start_cron_jobs', t => 60, async => TRUE ) or return;

  ($self->_start_cron_jobs or $self->autotrigger)
      and __trigger_output_handler( $daemon_pid );

   $self->lock->reset( k => 'start_cron_jobs' );
   return;
}

sub _get_listener_args {
   my $self   = shift;
   my $config = $self->config;
   my $args   = {
      '--port'       => $self->port,
      '--server'     => $self->server,
      '--access-log' => $config->logsdir->catfile( 'listener.log' ),
      '--app'        => $config->binsdir->catfile( 'mcp-listener' ), };

   return %{ $args };
}

sub _hangup_handler { # TODO: What should we do on reload?
}

sub _input_handler {
   my ($self, $daemon_pid, $notifier) = @_;

   while ($notifier->still_running) {
      my $trigger = $notifier->await_trigger;

      while ($trigger) {
         $trigger = FALSE;

         my $schema = $self->schema;
         my $ev_rs  = $schema->resultset( 'Event' );
         my $js_rs  = $schema->resultset( 'JobState' );
         my $pev_rs = $schema->resultset( 'ProcessedEvent' );
         my $events = $ev_rs->search
            ( { transition => [ qw(finish started terminate) ] },
              { order_by   => { -asc => 'me.id' },
                prefetch   => 'job_rel' } );

         for my $event ($events->all) {
            $schema->txn_do( sub {
               my $p_ev = $self->_process_event( $js_rs, $event );

               $p_ev->{rejected} or $trigger = TRUE;
               $pev_rs->create( $p_ev ); $event->delete;
            } );
         }

         $trigger and __trigger_output_handler( $daemon_pid );
      }

      __trigger_output_handler( $daemon_pid );
   }

   return;
}

sub _ipc_ssh_handler {
   my ($self, $runid, $user, $host, $calls) = @_;

   my $log    = $self->log;
   my $ips    = IPC::PerlSSH->new
      ( Host       => $host,
        User       => $user,
        SshOptions => [ '-i', $self->identity_file ], );
   my $logger = sub {
      my ($level, $cmd, $msg) = @_; $log->$level( "${cmd}[${runid}]: ${msg}" );
   };

   try        { $ips->use_library( $self->library_class ) }
   catch ($e) { $logger->( 'error', 'STORE', $e ); return FALSE }

   for my $call (@{ $calls }) {
      my $result;

      try        { $result = $ips->call( $call->[ 0 ], @{ $call->[ 1 ] } ) }
      catch ($e) { $logger->( 'error', ' CALL', $e ); return FALSE }

      $logger->( 'debug', ' CALL', $result );
   }

   return TRUE;
}

sub _output_handler {
   my ($self, $ipc_ssh, $notifier) = @_;

   while ($notifier->still_running) {
      my $trigger = $notifier->await_trigger;

      while ($trigger) {
         $trigger = FALSE;

         my $schema = $self->schema;
         my $ev_rs  = $schema->resultset( 'Event' );
         my $js_rs  = $schema->resultset( 'JobState' );
         my $pev_rs = $schema->resultset( 'ProcessedEvent' );
         my $events = $ev_rs->search( { transition => 'start' },
                                      { prefetch   => 'job_rel' } );

         for my $event ($events->all) {
            $schema->txn_do( sub {
               my $p_ev = $self->_process_event( $js_rs, $event );

               unless ($p_ev->{rejected}) {
                  my ($runid, $token)
                     = $self->_start_job( $ipc_ssh, $event->job_rel );

                  $p_ev->{runid} = $runid; $p_ev->{token} = $token;
                  $trigger = TRUE;
               }

               $pev_rs->create( $p_ev ); $event->delete;
            } );
         }
      }
   }

   return;
}

sub _process_event {
   my ($self, $js_rs, $event) = @_; my $r;

   my $cols = { $event->get_inflated_columns };

   if ($r = $js_rs->create_and_or_update( $event )) {
      $self->log->debug( (uc $r->[ 0 ]).'['.$r->[ 1 ].'] '.$r->[ 2 ] );
      $cols->{rejected} = $r->[ 2 ]->class;
   }

   return $cols;
}

sub _start_cron_jobs {
   my $self    = shift;
   my $trigger = FALSE;
   my $schema  = $self->schema;
   my $job_rs  = $schema->resultset( 'Job' );
   my $ev_rs   = $schema->resultset( 'Event' );
   my $jobs    = $job_rs->search( {
      'state.name'       => 'active',
      'crontab'          => { '!=' => undef   }, }, {
         'join'          => 'state' } )->search_related( 'events', {
            'transition' => { '!=' => 'start' } } );

   for my $job (grep { $job_rs->should_start_now( $_ ) } $jobs->all) {
      (not $job->condition or $job_rs->eval_condition( $job )->[ 0 ])
       and $trigger = TRUE
       and $ev_rs->create( { job_id => $job->id, transition => 'start' } );
   }

   return $trigger;
}

sub _start_job {
   my ($self, $ipc_ssh, $job) = @_; state $provisioned //= {};

   my $runid  = bson64id;
   my $host   = $job->host;
   my $user   = $job->user;
   my $cmd    = $job->command;
   my $class  = $self->config->appclass;
   my $token  = substr create_token, 0, 32;
   my $args   = { appclass  => $class,
                  command   => $cmd,
                  debug     => $self->debug,
                  directory => $job->directory,
                  job_id    => $job->id,
                  port      => $self->port,
                  runid     => $runid,
                  servers   => (join SPC, $self->servers),
                  token     => $token };
   my $calls  = [ [ 'dispatch', [ %{ $args } ] ], ];
   my $key    = "${user}\@${host}";

   $self->log->debug( "START[${runid}]: ${key} ${cmd}" );
   $provisioned->{ $key } or unshift @{ $calls }, [ 'provision', [ $class ] ];

   $ipc_ssh->call( $runid, $user, $host, $calls );

   $provisioned->{ $key } = TRUE;
   return ($runid, $token);
}

sub _stdio_file {
   my ($self, $extn, $name) = @_; $name ||= $self->config->name;

   return $self->file->tempdir->catfile( "${name}.${extn}" );
}

sub __trigger_output_handler {
   my $pid = shift; return CORE::kill 'USR2', $pid;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=head1 Name

App::MCP::Daemon - <One-line description of module's purpose>

=head1 Version

This documents version v0.2.$Rev: 7 $

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
