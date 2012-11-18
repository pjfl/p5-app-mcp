# @(#)$Id$

package App::MCP::Daemon;

use strict;
use feature qw(state);
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use Class::Usul::Moose;
use Class::Usul::Constants;
use Class::Usul::Functions       qw(create_token bson64id fqdn throw);
use Daemon::Control;
use English                      qw(-no_match_vars);
use File::DataClass::Constraints qw(File);
use IO::Async::Loop;
use IO::Async::Function;
use IO::Async::Signal;
use IO::Async::Timer::Periodic;
use IPC::PerlSSH::Async;
use Plack::Runner;
use POSIX                        qw(WEXITSTATUS);

extends q(Class::Usul::Programs);
with    q(CatalystX::Usul::TraitFor::ConnectInfo);

has 'database'      => is => 'ro',   isa => NonEmptySimpleStr,
   documentation    => 'The database to connect to',
   default          => 'schedule';

has 'identity_file' => is => 'ro',   isa => File, coerce => TRUE,
   documentation    => 'Path to private SSH key',
   default          => sub { [ $_[ 0 ]->config->my_home, qw(.ssh id_rsa) ] };

has '_loop'         => is => 'lazy', isa => Object, reader => 'loop',
   default          => sub { IO::Async::Loop->new };

has 'port'          => is => 'ro',   isa => PositiveInt, default => 2012,
   documentation    => 'Port number for the input event listener';

has '_schema'       => is => 'lazy', isa => Object, reader => 'schema';

has 'schema_class'  => is => 'lazy', isa => LoadableClass, coerce => TRUE,
   documentation    => 'Classname of the schema to load',
   default          => sub { 'App::MCP::Schema::Schedule' };

has 'server'        => is => 'ro',   isa => NonEmptySimpleStr,
   default          => 'Twiggy';

has '_servers'      => is => 'ro',   isa => ArrayRef,
   default          => sub { [ fqdn ] }, reader => 'servers';

around 'run' => sub {
   my ($next, $self, @args) = @_; $self->quiet( TRUE );

   return $self->$next( @args );
};

around 'run_chain' => sub {
   my ($next, $self, @args) = @_; @ARGV = @{ $self->extra_argv };

   my $config = $self->config; my $name = $config->name;

   Daemon::Control->new( {
      name         => blessed $self || $self,
      lsb_start    => '$syslog $remote_fs',
      lsb_stop     => '$syslog',
      lsb_sdesc    => 'Master Control Program',
      lsb_desc     => 'Controls the Master Control Program daemon.',
      path         => $config->pathname,

      directory    => $config->appldir,
      program      => sub { shift; $self->daemon( @_ ) },
      program_args => [],

      pid_file     => $config->rundir->catfile( "${name}.pid" ),
      stderr_file  => $self->_stdio_file( 'err' ),
      stdout_file  => $self->_stdio_file( 'out' ),

      fork         => 2,
   } )->run;

   return $self->$next( @args ); # Never reached
};

sub daemon {
   my $self = shift; my $loop = $self->loop;

   $self->log->info( "DAEMON[${PID}]: Starting event loop" );

   my $listener = $self->_start_listener;

   $self->log->info( "LISTEN[${listener}]: Starting listener" );

   my $oevt = IO::Async::Timer::Periodic->new
      ( interval   => 3,
        on_tick    => sub { $self->_output_event_handler },
        reschedule => 'drift', );

   my $hndl; $hndl = IO::Async::Signal->new( name => 'TERM', on_receipt => sub {
      $loop->remove( $hndl ); $oevt->stop; kill 15, $listener;
      $self->log->info( "LISTEN[${listener}]: Stopping listener" );
      $self->log->info( "DAEMON[${PID}]: Stopping event loop" );
      return;
   } );

   $loop->add( $hndl );
   $loop->add( $oevt );
   $oevt->start;
   $loop->run;
   return; # Never reached
}

# Private methods

sub _build__schema {
   my $self = shift;
   my $info = $self->get_connect_info( $self, { database => $self->database } );

   return $self->schema_class->connect( @{ $info } );
}

sub _get_ipsa {
   my ($self, $user, $host) = @_; my $errfile = $self->_stdio_file( 'err' );

   my $ipsa; $ipsa = IPC::PerlSSH::Async->new
      ( Host         => $host,
        User         => $user,
        SshOptions   => [ '-i', $self->identity_file ],
        on_exception => sub {
           $self->log->error( $_[ 0 ] ); $self->loop->remove( $ipsa );
        },
        on_exit      => sub {
           my $rv = $_[ 1 ] >> 8; $rv > 0
              and $self->log->error( "SSH[${host}]: See ${errfile} - rv ${rv}");
           $self->loop->remove( $ipsa );
        }, );

   $self->loop->add( $ipsa );
   return $ipsa;
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

sub _output_event_handler {
   my $self   = shift;
   my $ev_rs  = $self->schema->resultset( 'Event' );
   my $pev_rs = $self->schema->resultset( 'ProcessedEvent' );
   my $events = $ev_rs->search
      ( { 'state'    => 'starting', 'me.type' => 'job_start' },
        { '+columns' => [ qw(job_rel.command job_rel.directory
                             job_rel.host    job_rel.id
                             job_rel.user) ],
          'join'     => 'job_rel', } );

   for my $event ($events->all) {
      my ($runid, $token) = $self->_start_job( $event->job_rel );

      my $cols = { $event->get_inflated_columns };

      $cols->{runid} = $runid; $cols->{token} = $token;

      $pev_rs->create( $cols ); $event->delete;
   }

   state $tick //= 0; $self->log->debug( 'OTICK['.$tick++.']' );
   return;
}

sub _run_remote_command {
   my ($self, $ipsa, $key, $runid, $args) = @_; state $provisioned //= {};

   my $logger = sub {
      my ($method, $cmd, $msg) = @_;

      $self->log->$method( "${cmd}[${runid}]: ${msg}" );
   };

   my $loaded = sub {
      $provisioned->{ $key } or $ipsa->call
         ( name         => 'provision',
           args         => [ $self->config->appclass ],
           on_result    => sub { $logger->( 'debug', ' CALL', $_[ 0 ] ) },
           on_exception => sub { $logger->( 'error', ' CALL', $_[ 0 ] ) } );
      $provisioned->{ $key } = TRUE;
      $ipsa->call
         ( name         => 'dispatch',
           args         => $args,
           on_result    => sub { $logger->( 'debug', ' CALL', $_[ 0 ] ) },
           on_exception => sub { $logger->( 'error', ' CALL', $_[ 0 ] ) } );
      $ipsa->call
         ( name         => 'exit',
           args         => [],
           on_result    => sub { $logger->( 'debug', ' CALL', $_[ 0 ] ) },
           on_exception => sub { $logger->( 'debug', ' CALL', $_[ 0 ] ) } );
   };

   $ipsa->use_library
      ( library         => 'App::MCP::SSHLibrary',
        funcs           => [ qw(dispatch exit provision) ],
        on_exception    => sub { $logger->( 'error', 'STORE', $_[ 0 ] ) },
        on_loaded       => $loaded, );

   return;
}

sub _start_job {
   my ($self, $job) = @_;

   my $runid   = bson64id;
   my $user    = $job->user;
   my $host    = $job->host;
   my $cmd     = $job->command;
   my $key     = "${user}\@${host}";
   my $class   = $self->config->appclass;
   my $token   = substr create_token, 0, 32;
   my $servers = join SPC, @{ $self->servers };
   my $ipsa    = $self->_get_ipsa( $user, $host );
   my $args    = { appclass  => $class,         command   => $cmd,
                   debug     => $self->debug,   directory => $job->directory,
                   job_id    => $job->id,       port      => $self->port,
                   runid     => $runid,         servers   => $servers,
                   token     => $token };

   $self->log->debug( "START[${runid}]: ${key} ${cmd}" );

   $self->_run_remote_command( $ipsa, $key, $runid, [ %{ $args } ] );

   return ($runid, $token);
}

sub _start_listener {
   my $self = shift;

   return $self->loop->spawn_child
      ( code    => sub {
           Plack::Runner->run( $self->_get_listener_args ); return TRUE },
        on_exit => sub {
           my ($pid, $status, $bang, $e) = @_; my $rv = WEXITSTATUS( $status );

           $e and $self->log->error( "${e} - ${rv}" );
        }, );
}

sub _stdio_file {
   my ($self, $extn) = @_; my $name = $self->config->name;

   return $self->file->tempdir->catfile( "${name}.${extn}" );
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
