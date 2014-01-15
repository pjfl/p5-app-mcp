# @(#)Ident: Application.pm 2014-01-15 02:23 pjf ;

package App::MCP::Application;

use 5.010001;
use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.3.%d', q$Rev: 10 $ =~ /\d+/gmx );

use Moo;
use App::MCP::Constants;
use App::MCP::Functions     qw( log_leader trigger_input_handler
                                trigger_output_handler );
use Class::Usul::Crypt      qw( encrypt decrypt );
use Class::Usul::Functions  qw( bson64id bson64id_time
                                create_token elapsed throw );
use Class::Usul::Types      qw( LoadableClass NonZeroPositiveInt Object );
use HTTP::Status            qw( HTTP_BAD_REQUEST HTTP_CREATED HTTP_NOT_FOUND
                                HTTP_OK HTTP_UNAUTHORIZED );
use IPC::PerlSSH;
use JSON                    qw( );
use TryCatch;
use Unexpected::Functions   qw( Unspecified );

extends q(App::MCP);

my $Sessions = {}; my $Users = [];

# Public attributes
has 'port'          => is => 'lazy', isa => NonZeroPositiveInt,
   builder          => sub { $_[ 0 ]->config->port };

# Private attributes
has '_schema'       => is => 'lazy', isa => Object, builder => sub {
   my $self = shift; my $extra = $self->config->connect_params;
   $self->schema_class->connect( @{ $self->get_connect_info }, $extra ) },
   reader           => 'schema';

has '_schema_class' => is => 'lazy', isa => LoadableClass, builder => sub {
   $_[ 0 ]->config->schema_classes->{schedule} },
   reader           => 'schema_class';

has '_transcoder'   => is => 'lazy', isa => Object,
   builder          => sub { JSON->new }, reader => 'transcoder';

with q(Class::Usul::TraitFor::ConnectInfo);

# Public methods
sub clock_tick_handler {
   my ($self, $key, $cron) = @_; my $lead = log_leader 'debug', $key, elapsed;

   $self->log->debug( $lead.'Tick' ); $cron->trigger;
   return;
}

sub create_event {
   my ($self, $req) = @_;

   my $schema = $self->schema;
   my $run_id = $req->args->[ 0 ] // 'undef';
   my $pe_rs  = $schema->resultset( 'ProcessedEvent' )
                        ->search( { runid   => $run_id },
                                  { columns => [ 'token' ] } );
   my $pevent = $pe_rs->first
      or throw error => 'Runid [_1] not found',
               args  => [ $run_id ], rv => HTTP_NOT_FOUND;
   my $event  = $self->_authenticate_params
      ( $run_id, $pevent->token, $req->content->{event} );

   try        { $event = $schema->resultset( 'Event' )->create( $event ) }
   catch ($e) { throw error => $e, rv => HTTP_BAD_REQUEST }

   trigger_input_handler $ENV{MCP_DAEMON_PID};
   return ( HTTP_CREATED, 'Event '.$event->id.' created' );
}

sub create_job {
   my ($self, $req) = @_;

   my $sess = $self->_get_session( $req->args->[ 0 ] // 'undef' );
   my $job  = $self->_authenticate_params
      ( $sess->{key}, $sess->{token}, $req->content->{job} );

   $job->{owner} = $sess->{user_id}; $job->{group} = $sess->{role_id};

   try        { $job = $self->schema->resultset( 'Job' )->create( $job ) }
   catch ($e) { throw error => $e, rv => HTTP_BAD_REQUEST }

   return ( HTTP_CREATED, 'Job '.$job->id.' created' );
}

sub cron_job_handler {
   my ($self, $sig_hndlr_pid) = @_;

   my $trigger = FALSE;
   my $schema  = $self->schema;
   my $job_rs  = $schema->resultset( 'Job' );
   my $ev_rs   = $schema->resultset( 'Event' );
   my $jobs    = $job_rs->search( {
      'state.name'       => 'active',
      'me.crontab'       => { '!=' => NUL }, }, {
         'columns'       => [ qw( condition crontab id
                                  state.name state.updated ) ],
         'join'          => 'state' } );
#->search_related( 'events', {
#            'transition' => [ undef, { '!=' => 'start' } ] } );


   for my $job (grep { $_->should_start_now } $jobs->all) {
      (not $job->condition or $job->eval_condition) and $trigger = TRUE
       and $ev_rs->create( { job_id => $job->id, transition => 'start' } );
   }

   $trigger and trigger_output_handler $sig_hndlr_pid;
   return OK;
}

sub find_or_create_session {
   my ($self, $req) = @_; my $user_name = $req->args->[ 0 ] // 'undef';

   my $user_rs = $self->schema->resultset( 'User' ); my $user;

   try        { $user = $user_rs->find_by_name( $user_name ) }
   catch ($e) { throw error => $e, rv => HTTP_NOT_FOUND }

   $user->active or throw error => 'User [_1] account inactive',
                          args  => [ $user_name ], rv => HTTP_UNAUTHORIZED;

   my ($code, $sess) = $self->_find_or_create_session( $user );

   my $salt  = __get_salt( $user->password );
   my $res   = { id => $sess->{id}, token => $sess->{token}, };
   my $token = encrypt $user->password, $self->transcoder->encode( $res );

   return ( $code, { salt => $salt, token => $token } );
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
         ( { transition => [ qw( finish started terminate ) ] },
           { order_by   => { -asc => 'me.id' },
             prefetch   => 'job_rel' } );

      for my $event ($events->all) {
         $schema->txn_do( sub {
            my $p_ev = $self->_process_event( $js_rs, $event );

            $p_ev->{rejected} or $trigger = TRUE;
            $pev_rs->create( $p_ev ); $event->delete;
         } );
      }

      $trigger and trigger_output_handler $sig_hndlr_pid;
   }

   trigger_output_handler $sig_hndlr_pid;
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
sub _authenticate_params {
   my ($self, $key, $token, $params) = @_;

   $params or throw error => 'Request [_1] has no content',
                     args => [ $key ], rv => HTTP_UNAUTHORIZED;

   try { $params = $self->transcoder->decode( decrypt $token, $params ) }
   catch ($e) {
      $self->log->error( $e );
      throw error => 'Request [_1] authentication failed with token [_2]',
             args => [ $key, $token ], rv => HTTP_UNAUTHORIZED;
   }

   return $params;
}

sub _find_or_create_session {
   my ($self, $user) = @_; my $code = HTTP_OK; my $sess;

   try        { $sess = $self->_get_session( $Users->[ $user->id ] ) }
   catch ($e) { # Create a new session
      $self->log->debug( $e );

      my $id = $Users->[ $user->id ] = bson64id; $code = HTTP_CREATED;

      $sess = $Sessions->{ $id } = {
         id        => $id,
         key       => $user->username,
         last_used => bson64id_time( $id ),
         max_age   => $self->config->max_session_age,
         role_id   => $user->role_id,
         token     => create_token,
         user_id   => $user->id, };
   }

   return ($code, $sess);
}

sub _get_session {
   my ($self, $id) = @_;

   $id or throw class => Unspecified, args => [ 'session id' ],
                rv    => HTTP_BAD_REQUEST;

   my $sess = $Sessions->{ $id }
      or throw error => 'Session [_1 ] not found',
               args  => [ $id ], rv => HTTP_NOT_FOUND;

   my $max_age = $sess->{max_age}; my $now = time;

   $max_age and $now - $sess->{last_used} > $max_age
      and delete $Sessions->{ $id }
      and throw error => 'Session [_1] expired',
                args  => [ $id ], rv => HTTP_NOT_FOUND;
   $sess->{last_used} = $now;
   return $sess;
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
                 servers   => (join COMMA, @{ $self->config->servers }),
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

=encoding utf8

=head1 Name

App::MCP::Application - One-line description of the modules purpose

=head1 Synopsis

   use App::MCP::Application;
   # Brief but working code examples

=head1 Version

This documents version v0.1.$Rev: 1 $ of L<App::MCP::Application>

=head1 Description

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=back

=head1 Subroutines/Methods

=head1 Diagnostics

=head1 Dependencies

=over 3

=item L<Class::Usul>

=item L<IPC::PerlSSH>

=item L<TryCatch>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module. Please report problems to
http://rt.cpan.org/NoAuth/Bugs.html?Dist=App-MCP.
Patches are welcome

=head1 Acknowledgements

Larry Wall - For the Perl programming language

=head1 Author

Peter Flanigan, C<< <pjfl@cpan.org> >>

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
