# @(#)$Id$

package App::MCP::Daemon;

use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use Class::Usul::Moose;
use Class::Usul::Constants;
use Class::Usul::Functions       qw(create_token bson64id fqdn throw);
use App::MCP::DaemonControl;
use English                      qw(-no_match_vars);
use File::DataClass::Constraints qw(File Path);
use IO::Async::Loop::EV;
use IO::Async::Channel;
use IO::Async::Function;
use IO::Async::Routine;
use IO::Async::Signal;
use IO::Async::Timer::Periodic;
use IPC::PerlSSH;
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
   default            => sub { IO::Async::Loop::EV->new }, reader => 'loop';

has '_op_ev_hndlr'    => is => 'lazy', isa => Object, reader => 'op_ev_hndlr';

has '_schema'         => is => 'lazy', isa => Object,  reader => 'schema';

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

   $self->listener; $self->clock_tick;

   my $stop = sub {
      $loop->unwatch_signal( 'QUIT' ); $loop->unwatch_signal( 'TERM' );
      $self->_stop_everything;
   };

   $loop->watch_signal( QUIT => $stop );
   $loop->watch_signal( TERM => $stop );
   $loop->watch_signal( USR1 => sub { $self->_trigger_input_handler  } );
   $loop->watch_signal( USR2 => sub { $self->_trigger_output_handler } );

   try { $loop->run } catch ($e) { $log->error( $e ); $stop->() }

   exit OK;
}

# Private methods

sub _build__async_factory {
   return App::MCP::AsyncNotifierFactory->new( builder => $_[ 0 ] );
}

sub _build__clock_tick {
   my $self  = shift; my $daemon_pid = $PID;

   my $timer = IO::Async::Timer::Periodic->new
      (  on_tick    => sub { $self->_clock_tick_handler( $daemon_pid ) },
         interval   => $self->interval,
         reschedule => 'drift', );

   $timer->start; $self->loop->add( $timer );

   return $timer;
}

sub _build__ip_ev_hndlr {
   my $self = shift; my $daemon_pid = $PID;

   return $self->async_factory->new_notifier
      (  code => sub { $self->_input_handler( shift, $daemon_pid ) },
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
      (  code => sub { $self->_output_handler( shift ) },
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
   my ($self, $input, $daemon_pid) = @_;

   while ($input->recv) {
      my $trigger = TRUE; #__drain( $input );

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
   catch ($e) { $logger->( 'error', 'STORE', $e ); return }

   for my $call (@{ $calls }) {
      my $call_name = $call->[ 0 ]; my $result;
      $result = join "\n", $ips->call( $call_name, @{ $call->[ 1 ] } );
#      try { }
#      catch ($e) {
#         $logger->( $call_name eq 'exit' ? 'debug' : 'error', ' CALL', $e );

#         return $call_name eq 'exit' ? TRUE : FALSE;
#      }

      $logger->( 'debug', ' CALL', $result );
   }

   return;
}

sub _output_handler {
   my ($self, $input) = @_;

   while ($input->recv) {
      my $trigger = TRUE; #__drain( $input );

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

   # TODO: Fix me. Seriously fucked off with IO::Async
   for (grep { $_->pid } $self->ipc_ssh->_worker_objects) {
      $_->stop; kill 'KILL', $_->pid;
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
   my $calls  = [ [ 'dispatch', [ %{ $args } ] ],
                  [ 'exit',     [] ], ];
   my $key    = "${user}\@${host}";
   my $logger = sub {
      my ($level, $cmd, $msg) = @_; $log->$level( "${cmd}[${runid}]: ${msg}" );
   };

   $provisioned->{ $key } or unshift @{ $calls }, [ 'provision', [ $class ] ];
   $logger->( 'debug', 'START', "${key} ${cmd}" );
   $self->ipc_ssh->call
      (  args      => [ $user, $host, $runid, $calls ],
         on_return => sub { $logger->( 'debug', ' CALL', 'Complete' ) },
         on_error  => sub { $logger->( 'error', ' CALL', $_[ 0 ]    ) }, );
   $provisioned->{ $key } = TRUE;
   return ($runid, $token);
}

sub _stop_everything {
   my $self = shift; my $log = $self->log; my $loop = $self->loop;

   $self->clock_tick->stop;

   my $process = $self->listener; my $pid = $process->pid;

   $log->info( "LISTEN[${pid}]: Stopping listener" );
   $process->is_running and $process->kill( 'TERM' );

   $process = $self->ip_ev_hndlr; $pid = $process->pid;
   $log->info( " INPUT[${pid}]: Stopping input event handler" );
   $process->is_running and $process->{channels_in}->[ 0 ]->close;

   $process = $self->op_ev_hndlr; $pid = $process->pid;
   $log->info( "OUTPUT[${pid}]: Stopping output event handler" );
   $process->is_running and $process->{channels_in}->[ 0 ]->close;

   $log->info( "DAEMON[${PID}]: Event loop stopping" );
   sleep 4; # TODO: Fix me. This is crap
   return;
}

sub _stdio_file {
   my ($self, $extn, $name) = @_; $name ||= $self->config->name;

   return $self->file->tempdir->catfile( "${name}.${extn}" );
}

sub _trigger_input_handler {
   return $_[ 0 ]->ip_ev_hndlr->{channels_in}->[ 0 ]->send( [] );
}

sub _trigger_output_handler {
   return $_[ 0 ]->op_ev_hndlr->{channels_in}->[ 0 ]->send( [] );
}

# Private functions

sub __drain {
   return __read_all_from( $_[ 0 ]->{fh} );
}

sub __read_all_from {
   my $fh = shift; local $RS = undef; return <$fh>;
}

__PACKAGE__->meta->make_immutable;

package # Hide from indexer
   App::MCP::Process;

sub new { # Cannot get IO::Async::Process to plackup Twiggy, so this instead
   my $self    = shift;
   my $new     = bless { @_ }, ref $self || $self;
   my $builder = delete $new->{builder};
   my $r       = $builder->run_cmd( [ $new->{code} ], { async => 1 } );

   $builder->loop->watch_child( $new->{pid} = $r->{pid}, $new->{on_exit} );

   return $new;
}

sub is_running {
   return kill 0, $_[ 0 ]->pid;
}

sub kill {
   kill $_[ 1 ], $_[ 0 ]->pid;
}

sub pid {
   return $_[ 0 ]->{pid};
}

package # Hide from indexer
   App::MCP::AsyncNotifierFactory;

use POSIX        qw(WEXITSTATUS);
use Scalar::Util qw(weaken);

sub new {
   my $self = shift; my $new = bless { @_ }, ref $self || $self;

   weaken( $new->{builder} );

   return $new;
}

sub new_notifier {
   my ($self, %p) = @_; my $builder = $self->{builder}; my $code = $p{code};

   my $desc = $p{desc}; my $key = $p{key}; my $log = $builder->log;

   my $logger = sub {
      my ($level, $pid, $msg) = @_; $log->$level( "${key}[${pid}]: ${msg}" );
   };

   my $loop = $builder->loop; my $notifier; my $pid;

   if ($p{type} eq 'function') {
      $notifier = IO::Async::Function->new
         (  code        => $code,
            exit_on_die => 1,
            max_workers => $p{max_workers},
            setup       => [ $log->fh, [ 'keep' ] ], );

      $notifier->start; $loop->add( $notifier ); $pid = $notifier->workers;
   }
   elsif ($p{type} eq 'process') {
      $notifier = App::MCP::Process->new
         (  builder => $builder,
            code    => $code,
            on_exit => sub {
               my $pid = shift; my $rv = WEXITSTATUS( shift );

               $logger->( 'info', $pid, (ucfirst $desc)." stopped ${rv}" );
            }, );

      $pid = $notifier->pid;
   }
   else {
      my $input = IO::Async::Channel->new; my $msg = (ucfirst $desc).' stopped';

      $notifier = IO::Async::Routine->new
         (  channels_in  => [ $input ],
            code         => sub { $code->( $input ) },
            on_exception => sub { $logger->( 'error', $pid, join ' - ', @_ ) },
            on_finish    => sub { $logger->( 'info',  $pid, $msg ) },
            setup        => [ $log->fh, [ 'keep' ] ], );

      $loop->add( $notifier ); $pid = $notifier->pid;
   }

   $logger->( 'info', $pid, "Started ${desc}" );

   return $notifier;
}

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
