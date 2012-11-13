# @(#)$Id$

package App::MCP::Daemon;

use strict;
use feature qw(state);
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use Class::Usul::Moose;
use Class::Usul::Constants;
use Class::Usul::Functions qw(throw);
use Daemon::Control;
use IO::Async::Loop;
use IO::Async::Timer::Periodic;

extends q(Class::Usul::Programs);
with    q(CatalystX::Usul::TraitFor::ConnectInfo);

has 'database'     => is => 'ro',   isa => NonEmptySimpleStr,
   documentation   => 'The database to connect to',
   default         => 'schedule';

has '_schema'      => is => 'lazy', isa => Object, reader => 'schema';

has 'schema_class' => is => 'lazy', isa => LoadableClass, coerce => TRUE,
   documentation   => 'Classname of the schema to load',
   default         => sub { 'App::MCP::Schema::Schedule' };

around 'run' => sub {
   my ($next, $self, @args) = @_; $self->quiet( TRUE );

   return $self->$next( @args );
};

sub void : method {
   my ($self, $method) = @_; my $config  = $self->config;

   my $name = $config->name; my $tempdir = $self->file->tempdir;

   Daemon::Control->new( {
      name         => blessed $self || $self,
      lsb_start    => '$syslog $remote_fs',
      lsb_stop     => '$syslog',
      lsb_sdesc    => 'Master Control Program',
      lsb_desc     => 'Controls the Master Control Program daemon.',
      path         => $config->pathname,

      directory    => $config->appldir,
      program      => sub { shift; $self->loop( @_ ) },
      program_args => [],

      pid_file     => $config->rundir->catfile( "${name}.pid" ),
      stderr_file  => $tempdir->catfile( "${name}.err" ),
      stdout_file  => $tempdir->catfile( "${name}.out" ),

      fork         => 2,
   } )->run;

   return; # Never reached
}

sub loop {
   my $self = shift;
   my $loop = IO::Async::Loop->new;
   my $oevt = IO::Async::Timer::Periodic->new
      ( interval   => 3,
        on_tick    => sub { $self->_output_event_handler },
        reschedule => 'drift', );

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

sub _output_event_handler {
   my $self   = shift;
   my $rs     = $self->schema->resultset( 'Event' );
   my $events = $rs->search( { type => 'job_start' } );

   state $i //= 0; $self->log->info( 'Handler '.$i++.' '.$events->count );
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
