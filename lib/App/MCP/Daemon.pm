# @(#)$Id$

package App::MCP::Daemon;

use strict;
use feature qw(state);
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use Class::Usul::Moose;
use Class::Usul::Constants;
use Class::Usul::Functions       qw(bson64id throw);
use Daemon::Control;
use File::DataClass::Constraints qw(File);
use IO::Async::Loop;
use IO::Async::Signal;
use IO::Async::Timer::Periodic;
use IPC::PerlSSH::Async;

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

has '_schema'       => is => 'lazy', isa => Object, reader => 'schema';

has 'schema_class'  => is => 'lazy', isa => LoadableClass, coerce => TRUE,
   documentation    => 'Classname of the schema to load',
   default          => sub { 'App::MCP::Schema::Schedule' };

around 'run' => sub {
   my ($next, $self, @args) = @_; $self->quiet( TRUE );

   return $self->$next( @args );
};

sub void : method {
   my ($self, $method) = @_; @ARGV = @{ $self->extra_argv };

   my $config = $self->config; my $name = $config->name;

   Daemon::Control->new( {
      name         => blessed $self || $self,
      lsb_start    => '$syslog $remote_fs',
      lsb_stop     => '$syslog',
      lsb_sdesc    => 'Master Control Program',
      lsb_desc     => 'Controls the Master Control Program daemon.',
      path         => $config->pathname,

      directory    => $config->appldir,
      program      => sub { shift; $self->looper( @_ ) },
      program_args => [],

      pid_file     => $config->rundir->catfile( "${name}.pid" ),
      stderr_file  => $self->_stdio_file( 'err' ),
      stdout_file  => $self->_stdio_file( 'out' ),

      fork         => 2,
   } )->run;

   return; # Never reached
}

sub looper {
   my $self = shift;
   my $oevt = IO::Async::Timer::Periodic->new
      ( interval   => 3,
        on_tick    => sub { $self->_output_event_handler },
        reschedule => 'drift', );
   my $hndl; $hndl = IO::Async::Signal->new( name => 'TERM', on_receipt => sub {
      $self->loop->remove( $hndl ); $oevt->stop;
      $self->log->info( 'Stopping event loop' );
      return;
   } );

   $self->log->info( 'Starting event loop' );
   $self->loop->add( $hndl );
   $self->loop->add( $oevt );
   $oevt->start;
   $self->loop->run;
   return; # Never reached
}

# Private methods

sub _build__schema {
   my $self = shift;
   my $info = $self->get_connect_info( $self, { database => $self->database } );

   return $self->schema_class->connect( @{ $info } );
}

sub _output_event_handler {
   my $self   = shift;
   my $ev_rs  = $self->schema->resultset( 'Event' );
   my $arc_rs = $self->schema->resultset( 'EventArchive' );
   my $events = $ev_rs->search
      ( { 'state'    => 'starting',
          'me.type'  => 'job_start' },
        { '+columns' => [ qw(job_rel.command job_rel.host job_rel.user) ],
          'join'     => 'job_rel', } );

   $self->_start_job( $arc_rs, $_ ) for ($events->all);

   state $tick //= 0; $self->log->debug( 'OEHTICK['.$tick++.']' );
   return;
}

sub _get_ipsa {
   my ($self, $args) = @_;

   my $errfile = $self->_stdio_file( 'err' ); my $host = $args->{host};

   my $ipsa = IPC::PerlSSH::Async->new
      ( Host         => $host,
        User         => $args->{user},
        SshOptions   => [ '-i', $self->identity_file ],
        on_exception => sub { $self->log->error( $_[ 0 ] ) },
        on_exit      => sub {
           my $rv = $_[ 1 ] >> 8; $rv > 0
              and $self->log->error( "SSH[${host}]: See ${errfile} - rv ${rv}");
        }, );

   $self->loop->add( $ipsa );

   return $ipsa;
}

sub _start_job {
   my ($self, $arc_rs, $event) = @_;

   my $runid = bson64id;
   my $user  = $event->job_rel->user;
   my $host  = $event->job_rel->host;
   my $cmd   = $event->job_rel->command;
   my $ipsa  = $self->_get_ipsa( { host => $host, user => $user } );
   my $args  = { command => $cmd, runid => $runid };
   my $cols  = { $event->get_inflated_columns };

   $self->log->info( "START[${runid}]: ${user}\@${host} ${cmd}" );

   $ipsa->use_library
      ( library              => 'App::MCP::SSHLibrary',
        funcs                => [ 'run' ],
        on_exception         => sub {
           $self->log->error( "STOREPKG[$runid]: ".$_[ 0 ] ) },
        on_loaded            => sub {
           $ipsa->call
              ( name         => 'run',
                args         => [ $args ],
                on_result    => sub {
                   $self->log->info( "CALL[${runid}]: ".$_[ 0 ] ) },
                on_exception => sub {
                   $self->log->error( "CALL[${runid}]: ".$_[ 0 ] ) }, );
        }, );

   $cols->{runid} = $runid; $arc_rs->create( $cols ); $event->delete;

   return;
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
