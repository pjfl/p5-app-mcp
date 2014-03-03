package App::MCP::Schema::Schedule::ResultSet::JobState;

use 5.01;
use strictures;
use parent 'DBIx::Class::ResultSet';

use App::MCP::Constants;
use App::MCP::Workflow;
use Class::Usul::Functions qw( exception );
use DateTime;
use Scalar::Util           qw( blessed );
use TryCatch;
use Unexpected::Functions  qw( Unknown );

sub create_and_or_update {
   my ($self, $event) = @_;

   my $job        = $event->job_rel;
   my $job_state  = $self->find_or_create( $job );
   my $state_name = $job_state->name->value;

   try {
      $state_name = $self->_workflow->process_event( $state_name, $event );
   }
   catch ($e) {
      (blessed $e and $e->can( 'class' ))
         or $e = exception class => Unknown, error => $e;

      return [ $event->transition->value, $job->fqjn, $e ];
   }

   $job_state->name( $state_name );
   $job_state->updated( DateTime->now );
   $job_state->update;
   $self->_trigger_update_cascade( $event );
   return;
}

sub find_or_create {
   my ($self, $job) = @_; my $parent_state = 'active';

   my $job_state; $job_state = $self->find( $job->id ) and return $job_state;

   if ($job->parent_id and $job->id != $job->parent_id) {
      $parent_state = $self->find( $job->parent_id );
      $parent_state and $parent_state = $parent_state->name;
      $parent_state or  $parent_state = 'inactive';
   }

   my $initial_state = ($parent_state eq 'active'
                     or $parent_state eq 'running'
                     or $parent_state eq 'starting')
                     ?  'active' : 'inactive';

   return $self->create( { job_id  => $job->id,
                           name    => $initial_state,
                           updated => DateTime->now } );
}

# Private methods
sub _trigger_update_cascade {
   my ($self, $event) = @_; my $schema = $self->result_source->schema;

   state $ev_rs //= $schema->resultset( 'Event' );
   state $jc_rs //= $schema->resultset( 'JobCondition' );

   for ($jc_rs->search( { job_id => $event->job_rel->id } )->all) {
      $ev_rs->create( { job_id => $_->reverse_id, transition => 'start' } );
   }

   return;
}

sub _workflow {
   state $wf //= App::MCP::Workflow->new; return $wf;
}

1;

__END__

=pod

=head1 Name

App::MCP::Schema::Schedule::ResultSet::JobState - <One-line description of module's purpose>

=head1 Synopsis

   use App::MCP::Schema::Schedule::ResultSet::JobState;
   # Brief but working code examples

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
