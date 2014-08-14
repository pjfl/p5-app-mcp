package App::MCP::Application;

use feature 'state';
use namespace::autoclean;

use Moo;
use App::MCP::Constants    qw( FALSE NUL TRUE );
use App::MCP::Functions    qw( log_leader trigger_output_handler );
use Class::Usul::Functions qw( bson64id create_token elapsed );
use Class::Usul::Types     qw( BaseType LoadableClass
                               NonZeroPositiveInt Object );
use IPC::PerlSSH;
use Try::Tiny;

# Public attributes
has 'port'  => is => 'lazy', isa => NonZeroPositiveInt,
   builder  => sub { $_[ 0 ]->config->port };

has 'usul'  => is => 'ro', isa => BaseType,
   handles  => [ qw( config debug log ) ], init_arg => 'builder',
   required => TRUE;

# Private attributes
has '_schema'       => is => 'lazy', isa => Object, builder => sub {
   my $self = shift; my $extra = $self->config->connect_params;
   $self->schema_class->connect( @{ $self->get_connect_info }, $extra ) },
   reader           => 'schema';

has '_schema_class' => is => 'lazy', isa => LoadableClass, builder => sub {
   $_[ 0 ]->config->schema_classes->{ 'mcp-model' } },
   reader           => 'schema_class';

with q(Class::Usul::TraitFor::ConnectInfo);

# Public methods
sub clock_tick_handler {
   my ($self, $key, $cron) = @_; my $lead = log_leader 'debug', $key, elapsed;

   $self->log->debug( $lead.'Tick' ); $cron->trigger;
   return;
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
   my ($self, $runid, $user, $host, $calls) = @_;

   my $failed = FALSE; my $log = $self->log;

   my $logger = sub {
      my ($level, $key, $msg) = @_; my $lead = log_leader $level, $key, $runid;

      $log->$level( $lead.$msg ); return;
   };

   my $ips    = IPC::PerlSSH->new
      ( Host       => $host,
        User       => $user,
        SshOptions => [ '-i', $self->config->identity_file ], );

   try   { $ips->use_library( $self->config->library_class ) }
   catch { $logger->( 'error', 'STORE', $_ ); $failed = TRUE };

   $failed and return FALSE;

   for my $call (@{ $calls }) {
      my $result;

      try   { $result = $ips->call( $call->[ 0 ], @{ $call->[ 1 ] } ) }
      catch { $logger->( 'error', 'CALL', $_ ); $failed = TRUE };

      $failed and return FALSE; $logger->( 'debug', 'CALL', $result );
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
sub _process_event {
   my ($self, $js_rs, $event) = @_;

   my $cols = { $event->get_inflated_columns };
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

1;

__END__

=pod

=encoding utf8

=head1 Name

App::MCP::Application - One-line description of the modules purpose

=head1 Synopsis

   use App::MCP::Application;
   # Brief but working code examples

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
