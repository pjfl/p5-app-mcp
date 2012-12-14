# @(#)$Id$

package App::MCP::Daemon;

use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use Class::Usul::Moose;
use Class::Usul::Constants;
use Class::Usul::Functions       qw(create_token bson64id fqdn throw);
use App::MCP::Async;
use App::MCP::DaemonControl;
use English                      qw(-no_match_vars);
use File::DataClass::Constraints qw(File Path);
use IPC::PerlSSH;
use IPC::SysV                    qw(IPC_PRIVATE S_IRUSR S_IWUSR IPC_CREAT);
use IPC::Semaphore;
use Plack::Runner;
use TryCatch;

extends q(Class::Usul::Programs);
with    q(CatalystX::Usul::TraitFor::ConnectInfo);

has 'database'        => is => 'ro',   isa => NonEmptySimpleStr,
   documentation      => 'The database to connect to',
   default            => 'schedule';

has 'identity_file'   => is => 'lazy', isa => File, coerce => TRUE,
   documentation      => 'Path to private SSH key',
   default            => sub { [ $_[ 0 ]->config->my_home, qw(.ssh id_rsa) ] };

has 'max_ssh_workers' => is => 'ro',   isa => PositiveInt,
   documentation      => 'Maximum number of SSH worker processes',
   default            => 3;

has 'port'            => is => 'ro',   isa => PositiveInt,
   documentation      => 'Port number for the input event listener',
   default            => 2012;

has 'schema_class'    => is => 'lazy', isa => LoadableClass, coerce => TRUE,
   documentation      => 'Classname of the schema to load',
   default            => sub { 'App::MCP::Schema::Schedule' };

has 'server'          => is => 'ro',   isa => NonEmptySimpleStr,
   documentation      => 'Plack server class used for the event listener',
   default            => 'Twiggy';


has '_async_factory'  => is => 'lazy', isa => Object, reader => 'async_factory';

has '_clock_tick'     => is => 'lazy', isa => Object, reader => 'clock_tick';

has '_interval'       => is => 'ro',   isa => PositiveInt,
   default            => 3,         reader => 'interval';

has '_ip_ev_hndlr'    => is => 'lazy', isa => Object, reader => 'ip_ev_hndlr';

has '_ipc_ssh'        => is => 'lazy', isa => Object, reader => 'ipc_ssh';

has '_library_class'  => is => 'ro',   isa => NonEmptySimpleStr,
   default            => 'App::MCP::SSHLibrary', reader => 'library_class';

has '_listener'       => is => 'lazy', isa => Object, reader => 'listener';

has '_loop'           => is => 'lazy', isa => Object,
   default            => sub { $_[ 0 ]->async_factory->loop }, reader => 'loop';

has '_op_ev_hndlr'    => is => 'lazy', isa => Object, reader => 'op_ev_hndlr';

has '_schema'         => is => 'lazy', isa => Object, reader => 'schema';

has '_semaphore'      => is => 'lazy', isa => Object, reader => 'semaphore';

has '_servers'        => is => 'ro',   isa => ArrayRef, auto_deref => TRUE,
   default            => sub { [ fqdn ] }, reader => 'servers';

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
      lsb_desc     => 'Controls the Master Control Program daemon',
      path         => $config->pathname,

      directory    => $config->appldir,
      program      => sub { shift; $self->daemon( @_ ) },
      program_args => [],

      pid_file     => $config->rundir->catfile( "${name}.pid" ),
      stderr_file  => $self->_stdio_file( 'err' ),
      stdout_file  => $self->_stdio_file( 'out' ),

      fork         => 2,
      stop_signals => 'TERM,5,KILL,1',
   } )->run;

   return $self->$next( @args ); # Never reached
};

sub daemon {
   my $self = shift; my $log = $self->log; my $loop = $self->loop;

   $log->info( "DAEMON[${PID}]: Starting event loop" );

   $self->semaphore; $self->listener;

   $self->ip_ev_hndlr; $self->op_ev_hndlr; $self->clock_tick;

   my $stop; $stop = sub {
      $loop->detach_signal( QUIT => $stop );
      $loop->detach_signal( TERM => $stop );
      $self->_stop_everything;
      $loop->watch_child( 0, sub {} );
      $self->semaphore->remove;
   };

   $loop->attach_signal( QUIT => $stop );
   $loop->attach_signal( TERM => $stop );
   $loop->attach_signal( USR1 => sub { $self->_trigger_input_handler  } );
   $loop->attach_signal( USR2 => sub { $self->_trigger_output_handler } );

   try { $loop->run } catch ($e) { $log->error( $e ); $stop->() }

   exit OK;
}

# Private methods

sub _build__async_factory {
   return App::MCP::Async->new( builder => $_[ 0 ] );
}

sub _build__clock_tick {
   my $self = shift; my $daemon_pid = $PID;

   return $self->async_factory->new_notifier
      (  code     => sub { $self->_clock_tick_handler( $daemon_pid ) },
         interval => $self->interval,
         desc     => 'clock tick handler',
         key      => '  TICK',
         type     => 'timer' );
}

sub _build__ip_ev_hndlr {
   my $self = shift; my $daemon_pid = $PID;

   return $self->async_factory->new_notifier
      (  code => sub { $self->_input_handler( $daemon_pid ) },
         desc => 'input event handler',
         key  => ' INPUT',
         type => 'routine' );
}

sub _build__ipc_ssh {
   my $self = shift;

   return $self->async_factory->new_notifier
      (  code        => sub { $self->_ipc_ssh_handler( @_ ) },
         desc        => 'ipc ssh workers',
         key         => 'IPCSSH',
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
   my $self = shift;

   return $self->async_factory->new_notifier
      (  code => sub { $self->_output_handler },
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

sub _build__semaphore {
   my $s = IPC::Semaphore->new( IPC_PRIVATE, 4, S_IRUSR | S_IWUSR | IPC_CREAT );

   $s->setval( 0, TRUE ); $s->setval( 1, FALSE );
   $s->setval( 2, TRUE ); $s->setval( 3, FALSE );

   return $s;
}

sub _clock_tick_handler {
   my ($self, $daemon_pid) = @_;

   state $tick //= 0; my $elapsed = $tick++ * $self->interval;

   $self->log->debug( " TICK[${elapsed}]" );
   $self->_start_cron_jobs;
   kill 'USR2', $daemon_pid;
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

sub _input_handler {
   my ($self, $daemon_pid) = @_; my $semaphore = $self->semaphore;

   while ($semaphore->getval( 0 )) {
      $semaphore->op( 1, -1, 0 ); my $trigger = TRUE;

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

         $trigger and kill 'USR2', $daemon_pid;
      }

      kill 'USR2', $daemon_pid;
   }

   return;
}

sub _ipc_ssh_handler {
   my ($self, $user, $host, $runid, $calls) = @_;

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

sub _ipc_ssh_stop { # TODO: Fix me. Seriously fucked off with IO::Async
   my $self = shift;

   for (grep { $_->pid } $self->ipc_ssh->_worker_objects) {
      $_->stop; kill 'KILL', $_->pid;
   }

   return;
}

sub _output_handler {
   my $self = shift; my $semaphore = $self->semaphore;

   while ($semaphore->getval( 2 )) {
      $self->semaphore->op( 3, -1, 0 ); my $trigger = TRUE;

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
                  my ($runid, $token) = $self->_start_job( $event->job_rel );

                  $p_ev->{runid} = $runid; $p_ev->{token} = $token;
                  $trigger = TRUE;
               }

               $pev_rs->create( $p_ev ); $event->delete;
            } );
         }
      }
   }

   $self->_ipc_ssh_stop;
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
   my $self   = shift;
   my $schema = $self->schema;
   my $job_rs = $schema->resultset( 'Job' );
   my $ev_rs  = $schema->resultset( 'Event' );
   my $jobs   = $job_rs->search( {
      'state.name'       => 'active',
      'crontab'          => { '!=' => undef   }, }, {
         'join'          => 'state' } )->search_related( 'events', {
            'transition' => { '!=' => 'start' } } );

   for my $job (grep { $job_rs->should_start_now( $_ ) } $jobs->all) {
      (not $job->condition or $job_rs->eval_condition( $job )->[ 0 ])
         and $ev_rs->create( { job_id => $job->id, transition => 'start' } );
   }

   return;
}

sub _start_job {
   my ($self, $job) = @_; my $log = $self->log; state $provisioned //= {};

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
   my $logger = sub {
      my ($level, $cmd, $msg) = @_; $log->$level( "${cmd}[${runid}]: ${msg}" );
   };

   $provisioned->{ $key } or unshift @{ $calls }, [ 'provision', [ $class ] ];
   $logger->( 'debug', 'START', "${key} ${cmd}" );

   my $task   = $self->ipc_ssh->call
      (  args      => [ $user, $host, $runid, $calls ],
         on_return => sub { $logger->( 'debug', ' CALL', 'Complete' ) },
         on_error  => sub { $logger->( 'error', ' CALL', $_[ 0 ]    ) }, );

   $provisioned->{ $key } = TRUE;

   return ($runid, $token);
}

sub _stop_everything {
   my $self = shift; my $log = $self->log; $self->clock_tick->stop;

   my $process = $self->listener; my $pid = $process->pid;

   $log->info( "LISTEN[${pid}]: Stopping listener" );
   $process->is_running and $process->kill( 'TERM' );

   $process = $self->ip_ev_hndlr; $pid = $process->pid;
   $log->info( " INPUT[${pid}]: Stopping input event handler" );
   $process->is_running and $self->semaphore->setval( 0, FALSE );

   $process = $self->op_ev_hndlr; $pid = $process->pid;
   $log->info( "OUTPUT[${pid}]: Stopping output event handler" );
   $process->is_running and $self->semaphore->setval( 2, FALSE );

   $log->info( "DAEMON[${PID}]: Event loop stopping" );
   return;
}

sub _stdio_file {
   my ($self, $extn, $name) = @_; $name ||= $self->config->name;

   return $self->file->tempdir->catfile( "${name}.${extn}" );
}

sub _trigger_input_handler {
   my $semaphore = $_[ 0 ]->semaphore;

   $semaphore->getval( 1 ) < 1 and $semaphore->op( 1, 1, 0 );

   return;
}

sub _trigger_output_handler {
   my $semaphore = $_[ 0 ]->semaphore;

   $semaphore->getval( 3 ) < 1 and $semaphore->op( 3, 1, 0 );

   return;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=head1 Name

App::MCP::Boss - <One-line description of module's purpose>

=head1 Version

0.1.$Revision$

=head1 Synopsis

   use App::MCP::Boss;
   # Brief but working code examples

=head1 Description

=head1 Configuration and Environment

=head1 Subroutines/Methods

=head2 looper

=head2 void

=head1 Diagnostics

=head1 Dependencies

=over 3

=item L<Class::Usul>

=item L<Daemon::Control>

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

Copyright (c) 2012 Peter Flanigan. All rights reserved

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
