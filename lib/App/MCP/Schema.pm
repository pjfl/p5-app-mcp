# @(#)$Ident: Schema.pm 2013-09-19 00:38 pjf ;

package App::MCP::Schema;

use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.3.%d', q$Rev: 3 $ =~ /\d+/gmx );

use Class::Usul::Constants;
use Class::Usul::Functions  qw( throw );
use Class::Usul::Types      qw( LoadableClass Object );
use Moo;

extends q(CatalystX::Usul::Schema);

my ($schema_version)  = $VERSION =~ m{ (\d+\.\d+) }mx;

# Public attributes (override defaults in base class)
has '+config_class'   => default => 'App::MCP::Config';

has '+database'       => default => sub { $_[ 0 ]->config->database };

has '+schema_classes' => default => sub { $_[ 0 ]->config->schema_classes };

has '+schema_version' => default => $schema_version;

# Private attributes
has '_schedule'       => is => 'lazy', isa => Object, reader => 'schedule';

has '_schedule_class' => is => 'lazy', isa => LoadableClass,
   default            => sub { $_[ 0 ]->schema_classes->{schedule} },
   reader             => 'schedule_class';

# Public methods
sub dump_jobs : method {
   my $self     = shift;
   my $job_spec = $self->next_argv || '%';
   my $path     = $self->next_argv || 'jobs.json';
   my $job_rs   = $self->schedule->resultset( 'Job' )->search( {
      fqjn => { like => $job_spec }, }, {
         result_class => 'DBIx::Class::ResultClass::HashRefInflator',
      } );

   $self->file->data_dump( { data => [ $job_rs->all ], path => $path, } );
   return OK;
}

sub load_jobs : method {
   my $self     = shift;
   my $path     = $self->next_argv || 'jobs.json';
   my $job_rs   = $self->schedule->resultset( 'Job' );

   return OK;
}

sub send_event : method {
   my $self     = shift;
   my $job_name = $self->next_argv or throw 'No job name';
   my $trans    = $self->next_argv || 'start';
   my $fqjn     = __fully_qualify( $job_name );
   my $schema   = $self->schedule;
   my $event_rs = $schema->resultset( 'Event' );
   my $job_id   = $schema->resultset( 'Job' )->job_id_by_name( $fqjn );

   $event_rs->create( { job_id => $job_id, transition => $trans } );
   return OK;
}

# Private methods
sub _build__schedule {
   my $self = shift; my $params = { quote_names => TRUE };

   return $self->schedule_class->connect( @{ $self->connect_info }, $params );
}

# Private functions
sub __fully_qualify {
   my $name = shift; return $name =~ m{ :: }mx ? $name : "main::${name}";
}

1;

__END__

=pod

=head1 Name

App::MCP::Schema - <One-line description of module's purpose>

=head1 Version

This documents version v0.3.$Rev: 3 $

=head1 Synopsis

   use App::MCP::Schema;
   # Brief but working code examples

=head1 Description

=head1 Configuration and Environment

=head1 Subroutines/Methods

=head2 dump_jobs - Dump selected job definitions to a file

=head2 load_jobs - Load job table dump file

=head2 send_event - Create a job state transition event

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
