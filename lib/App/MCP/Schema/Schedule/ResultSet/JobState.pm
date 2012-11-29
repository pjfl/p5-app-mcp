# @(#)$Id$

package App::MCP::Schema::Schedule::ResultSet::JobState;

use strict;
use feature qw(state);
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );
use parent  qw(DBIx::Class::ResultSet);

use Class::Usul::Constants;
use Class::Usul::Functions qw(exception throw);
use Algorithm::Cron;
use App::MCP::ExpressionParser;
use App::MCP::Workflow;
use DateTime;
use Scalar::Util           qw(blessed);
use TryCatch;

sub create_and_or_update {
   my ($self, $event) = @_;

   my $job        = $event->job_rel;
   my $job_state  = $self->_find_or_create( $job );
   my $state_name = $job_state->name->value;

   try {
      $state_name = $self->_workflow->process_event( $state_name, $event );
   }
   catch ($e) {
      (blessed $e and $e->can( 'class' ))
         or $e = exception error => $e, class => 'Unknown';

      return [ $event->transition->value, $job->fqjn, $e ];
   }

   $job_state->name( $state_name );
   $job_state->updated( DateTime->now );
   $job_state->update;
   $self->_trigger_update_cascade( $event );
   return;
}

sub eval_condition {
   my ($self, $job) = @_;

   state $parser //= App::MCP::ExpressionParser->new
      ( external => $self, predicates => $self->predicates );

   return $parser->parse( $job->condition, $job->namespace );
}

sub finished {
   my ($self, $fqjn) = @_; my $state = $self->_get_job_state( $fqjn );

   return $state eq 'finished' ? TRUE : FALSE ;
}

sub predicates {
   return [ qw(finished running terminated) ];
}

sub running {
   my ($self, $fqjn) = @_; my $state = $self->_get_job_state( $fqjn );

   return $state eq 'running' ? TRUE : FALSE
}

sub should_start_now {
   my ($self, $job) = @_;

   my $crontab   = $job->crontab;
   my $last_time = $job->state ? $job->state->updated->epoch : 0;
   my $cron      = Algorithm::Cron->new( base => 'utc', crontab => $crontab );
   my $time      = $cron->next_time( $last_time );

   return time > $time ? TRUE : FALSE;
}

sub terminated {
   my ($self, $fqjn) = @_; my $state = $self->_get_job_state( $fqjn );

   return $state eq 'terminated' ? TRUE : FALSE;
}

# Private methods

sub _find_or_create {
   my ($self, $job) = @_; my $parent_state = 'inactive';

   my $job_state; $job_state = $self->find( $job->id ) and return $job_state;

   if ($job->parent_id and $job->id != $job->parent_id) {
      $parent_state = $self->find( $job->parent_id );
      $parent_state and $parent_state = $parent_state->name;
   }
   else { $parent_state = 'active' }

   my $initial_state = ($parent_state eq 'active'
                     or $parent_state eq 'running'
                     or $parent_state eq 'starting')
                     ?  'active' : 'inactive';

   return $self->create( { job_id  => $job->id,
                           name    => $initial_state,
                           updated => DateTime->now } );
}

sub _get_job_state {
   my ($self, $fqjn) = @_;

   state $rs //= $self->result_source->schema->resultset( 'Job' );

   my $jobs = $rs->search( { fqjn => $fqjn }, { prefetch => 'state' } );
   my $job  = $jobs->first or throw error => 'Job [_1] unknown',
                                    args  => [ $fqjn ];

   return $job->state ? $job->state->name : 'inactive';
}

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

=head1 Version

0.1.$Revision$

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
