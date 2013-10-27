# @(#)$Ident: MCP.pm 2013-10-27 17:42 pjf ;

package App::MCP;

use 5.010001;
use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.3.%d', q$Rev: 6 $ =~ /\d+/gmx );

use App::MCP::Functions     qw( log_leader trigger_input_handler
                                trigger_output_handler );
use Class::Usul::Constants;
use Class::Usul::Crypt      qw( encrypt decrypt );
use Class::Usul::Functions  qw( base64_encode_ns bson64id bson64id_time
                                create_token elapsed );
use Class::Usul::Types      qw( BaseType LoadableClass
                                NonZeroPositiveInt Object );
use IPC::PerlSSH;
use Moo;
use Storable                qw( nfreeze thaw );
use TryCatch;

my $Sessions = {}; my $Users = [];

# Public attributes
has 'port'          => is => 'lazy', isa => NonZeroPositiveInt,
   builder          => sub { $_[ 0 ]->config->port };

# Private attributes
has '_schema'       => is => 'lazy', isa => Object,
   builder          => sub {
      my $self = shift; my $extra = $self->config->connect_params;
      $self->schema_class->connect( @{ $self->get_connect_info }, $extra ) },
   reader           => 'schema';

has '_schema_class' => is => 'lazy', isa => LoadableClass,
   builder          => sub { $_[ 0 ]->config->schema_classes->{schedule} },
   reader           => 'schema_class';

has '_usul'         => is => 'ro',   isa => BaseType,
   handles          => [ qw( config debug log ) ], init_arg => 'builder',
   required         => TRUE, weak_ref => TRUE;

with q(CatalystX::Usul::TraitFor::ConnectInfo);

# Public methods
sub clock_tick_handler {
   my ($self, $key, $cron) = @_; my $lead = log_leader 'debug', $key, elapsed;

   $self->log->debug( $lead.'Tick' ); $cron->trigger;
   return;
}

sub create_event {
   my ($self, $run_id, $params) = @_;

   my $schema = $self->schema;
   my $pe_rs  = $schema->resultset( 'ProcessedEvent' )
                        ->search( { runid   => $run_id },
                                  { columns => [ 'token' ] } );
   my $event  = $pe_rs->first or return ( 404, 'Run id not found' );
   my $ev_rs  = $schema->resultset( 'Event' );

   try        { $ev_rs->create( thaw decrypt $event->token, $params->{event} ) }
   catch ($e) { $self->log->error( $e ); return ( 400, $e ) }

   trigger_input_handler $ENV{MCP_DAEMON_PID};
   return ( 201, 'Event created' );
}

sub create_job {
   my ($self, $sess_id, $params) = @_;

   my $sess = $self->_get_session( $sess_id )
      or return ( 401, 'Session not found' );
   my $job  = $self->_get_authenticated_params( $sess, $params->{job} )
      or return ( 401, 'Authentication failure' );

   $job->{owner} = $sess->{user}->id; # TODO: Add job group

   try        { $self->schema->resultset( 'Job' )->create( $job ) }
   catch ($e) { $self->log->error( $e ); return ( 400, $e ) }

   return ( 201, 'Job created' );
}

sub cron_job_handler {
   my ($self, $sig_hndlr_pid) = @_;

   my $trigger = FALSE;
   my $schema  = $self->schema;
   my $job_rs  = $schema->resultset( 'Job' );
   my $ev_rs   = $schema->resultset( 'Event' );
   my $jobs    = $job_rs->search( {
      'state.name'       => 'active',
      'me.crontab'       => { '!=' => q() }, }, {
         'columns'       => [ qw(condition crontab id
                                 state.name state.updated) ],
         'join'          => 'state' } );
#->search_related( 'events', {
#            'transition' => [ undef, { '!=' => 'start' } ] } );


   for my $job (grep { $_->should_start_now } $jobs->all) {
      (not $job->condition or $job->eval_condition) and $trigger = TRUE
       and $ev_rs->create( { job_id => $job->id, transition => 'start' } );
   }

   $trigger and trigger_output_handler( $sig_hndlr_pid );
   return OK;
}

sub find_or_create_session {
   my ($self, $user_name) = @_; my $user;

   my $user_rs = $self->schema->resultset( 'User' );

   try        { $user = $user_rs->find_by_name( $user_name ) }
   catch ($e) { $self->log->error( $e ); return ( 404, "${e}" ) }

   my $code = 200; my $sess;

   unless ($sess = $self->_get_session_for_user( $user )) {
      $sess = $self->_create_session( $user ); $code = 201;
   }

   my $salt = __get_salt( $user->password );
   my $iced = nfreeze { id => $sess->{id}, token => $sess->{token}, };
   my $res  = { salt => $salt, token => encrypt $user->password, $iced };

   return (200, base64_encode_ns nfreeze $res);
}

sub input_handler {
   my ($self, $sig_hndlr_pid) = @_; my $trigger = TRUE;

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

      $trigger and trigger_output_handler( $sig_hndlr_pid );
   }

   trigger_output_handler( $sig_hndlr_pid );
   return OK;
}

sub ipc_ssh_handler {
   my ($self, $runid, $user, $host, $calls) = @_; my $log = $self->log;

   my $logger = sub {
      my ($level, $key, $msg) = @_; my $lead = log_leader $level, $key, $runid;

      $log->$level( $lead.$msg ); return;
   };

   my $ips    = IPC::PerlSSH->new
      ( Host       => $host,
        User       => $user,
        SshOptions => [ '-i', $self->config->identity_file ], );

   try        { $ips->use_library( $self->config->library_class ) }
   catch ($e) { $logger->( 'error', 'STORE', $e ); return FALSE }

   for my $call (@{ $calls }) {
      my $result;

      try        { $result = $ips->call( $call->[ 0 ], @{ $call->[ 1 ] } ) }
      catch ($e) { $logger->( 'error', 'CALL', $e ); return FALSE }

      $logger->( 'debug', 'CALL', $result );
   }

   return TRUE;
}

sub output_handler {
   my ($self, $ipc_ssh) = @_; my $trigger = TRUE;

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

   return OK;
}

# Private methods
sub _create_session {
   my ($self, $user) = @_; my $id = $Users->[ $user->id ] = bson64id;

   return $Sessions->{ $id } = { id        => $id,
                                 last_used => bson64id_time( $id ),
                                 max_age   => $self->config->max_session_age,
                                 token     => create_token,
                                 user      => $user, };
}

sub _get_authenticated_params {
   my ($self, $sess, $params) = @_; my $user_name = $sess->{user}->username;

   try        { $params = thaw decrypt $sess->{token}, $params }
   catch ($e) {
      $self->log->warn( "User ${user_name} - authentication failure" );
      $self->debug and $self->log->debug( $e );
      return;
   }

   return $params;
}

sub _get_session {
   my ($self, $id) = @_; $id or return; my $now = time;

   my $sess = $Sessions->{ $id } or return; my $max_age = $sess->{max_age};

   $max_age and $now - $sess->{last_used} > $max_age
      and delete $Sessions->{ $id } and return;
   $sess->{last_used} = $now;
   return $sess;
}

sub _get_session_for_user {
   return $_[ 0 ]->_get_session( $Users->[ $_[ 1 ]->id ] );
}

sub _process_event {
   my ($self, $js_rs, $event) = @_; my $cols = { $event->get_inflated_columns };

   my $r    = $js_rs->create_and_or_update( $event ) or return $cols;

   my $lead = log_leader 'debug', uc $r->[ 0 ], $r->[ 1 ];

   $self->log->debug( $lead.$r->[ 2 ] );
   $cols->{rejected} = $r->[ 2 ]->class;
   return $cols;
}

sub _start_job {
   my ($self, $ipc_ssh, $job) = @_; state $provisioned //= {};

   my $runid = bson64id;
   my $host  = $job->host;
   my $user  = $job->user;
   my $cmd   = $job->command;
   my $class = $self->config->appclass;
   my $token = substr create_token, 0, 32;
   my $args  = { appclass  => $class,
                 command   => $cmd,
                 debug     => $self->debug,
                 directory => $job->directory,
                 job_id    => $job->id,
                 port      => $self->port,
                 runid     => $runid,
                 servers   => (join SPC, @{ $self->config->servers }),
                 token     => $token };
   my $calls = [ [ 'dispatch', [ %{ $args } ] ], ];
   my $lead  = log_leader 'debug', 'START', $runid;
   my $key   = "${user}\@${host}";

   $self->log->debug( "${lead}${key} ${cmd}" );
   $provisioned->{ $key } or unshift @{ $calls }, [ 'provision', [ $class ] ];

   $ipc_ssh->call( $runid, $user, $host, $calls ); # Calls ipc_ssh_handler

   $provisioned->{ $key } = TRUE;
   return ($runid, $token);
}

# Private functions
sub __get_salt {
   my $password = shift; my @parts = split m{ [\$] }mx, $password;

   $parts[ -1 ] = substr $parts[ -1 ], 0, 22;

   return join '$', @parts;
}

1;

__END__

=pod

=head1 Name

App::MCP - Master Control Program - Dependency and time based job scheduler

=head1 Version

This documents version v0.3.$Rev: 6 $

=head1 Synopsis

   use App::MCP::Daemon;

   exit App::MCP::Daemon->new_with_options
      ( appclass => 'App::MCP', noask => 1 )->run;

=head1 Description

=head1 Configuration and Environment

=head1 Subroutines/Methods

=head1 Diagnostics

=head1 Dependencies

=over 3

=item L<CatalystX::Usul::TraitFor::ConnectInfo>

=item L<Class::Usul>

=item L<IPC::PerlSSH>

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

