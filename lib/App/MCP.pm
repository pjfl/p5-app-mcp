# @(#)$Ident: MCP.pm 2013-05-30 13:45 pjf ;

package App::MCP;

use 5.01;
use strict;
use version; our $VERSION = qv( sprintf '0.2.%d', q$Rev: 12 $ =~ /\d+/gmx );

use App::MCP::Functions     qw(log_leader trigger_output_handler);
use Class::Usul::Moose;
use Class::Usul::Constants;
use Class::Usul::Functions  qw(create_token bson64id);
use IPC::PerlSSH;
use TryCatch;

# Public attributes
has 'schema'         => is => 'lazy', isa => Object;

has 'schema_class'   => is => 'lazy', isa => LoadableClass, coerce => TRUE,
   default           => sub { $_[ 0 ]->config->schema_class };

has 'servers'        => is => 'lazy', isa => ArrayRef, auto_deref => TRUE,
   default           => sub { $_[ 0 ]->config->servers };

# Private attributes
has '_builder'       => is => 'ro',   isa => Object,
   handles           => [ qw(config database debug identity_file log port) ],
   init_arg          => 'builder', reader => 'builder', required => TRUE;

has '_library_class' => is => 'ro',   isa => NonEmptySimpleStr,
   default           => 'App::MCP::SSHLibrary', reader => 'library_class';

with q(CatalystX::Usul::TraitFor::ConnectInfo);

# Public methods
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
        SshOptions => [ '-i', $self->identity_file ], );

   try        { $ips->use_library( $self->library_class ) }
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

sub start_cron_jobs {
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

# Private methods
sub _build_schema {
   my $self = shift;
   my $info = $self->get_connect_info( $self, { database => $self->database } );

   my $params = { quote_names => TRUE }; # TODO: Fix me

   return $self->schema_class->connect( @{ $info }, $params );
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

1;

__END__

=pod

=head1 Name

App::MCP - Master Control Program - Dependency and time based job scheduler

=head1 Version

This documents version v0.2.$Rev: 12 $

=head1 Synopsis

   use App::MCP::Daemon;

   exit App::MCP::Daemon->new_with_options
      ( appclass => 'App::MCP', nodebug => 1 )->run;

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

