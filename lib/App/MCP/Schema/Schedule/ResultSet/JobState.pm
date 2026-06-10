package App::MCP::Schema::Schedule::ResultSet::JobState;

use App::MCP::Constants    qw( EXCEPTION_CLASS FALSE NUL TRUE );
use Unexpected::Types      qw( ArrayRef HashRef );
use Unexpected::Functions  qw( Native Unspecified );
use Class::Usul::Cmd::Util qw( includes );
use English                qw( -no_match_vars );
use Scalar::Util           qw( blessed );
use Web::Components::Util  qw( exception throw );
use App::MCP::Workflow;
use Try::Tiny;
use Moo;

extends 'DBIx::Class::ResultSet';

=pod

=head1 Name

App::MCP::Schema::Schedule::ResultSet::JobState - Job state collection class

=head1 Synopsis

   use Moo;

   with 'App::MCP::Role::Schema';

   my $rs = $self->schema->resultset('JobState');

=head1 Description

Job state collection class

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=item C<event_propagation>

Hash reference containig lookup tables for forward and reverse event propagation

=cut

has 'event_propagation' =>
   is      => 'ro',
   isa     => HashRef,
   default => sub {
      return {
         'forward' => {
            'activate'    => 'activate',
            'deactivate'  => 'deactivate',
            'fail'        => 'start',
            'finish'      => 'start',
            'force_start' => NUL,
            'off_hold'    => 'activate',
            'on_hold'     => 'deactivate',
            'start'       => NUL,
            'started'     => 'start',
            'terminate'   => 'start',
         },
         'reverse' => {
            'activate'    => NUL,
            'deactivate'  => NUL,
            'fail'        => 'finish',
            'finish'      => 'finish',
            'force_start' => NUL,
            'off_hold'    => NUL,
            'on_hold'     => NUL,
            'start'       => NUL,
            'started'     => NUL,
            'terminate'   => 'finish',
         }
      };
   };

=item C<initially_active>

An array reference of states that are initially active if their parent is
active

=cut

has 'initially_active' =>
   is      => 'ro',
   isa     => ArrayRef,
   default => sub { [qw(active running starting)] };

=back

=head1 Subroutines/Methods

Defines the following methods;

=over 3

=item C<create_and_or_update>

   $tuple = $self->create_and_or_update($event);

=cut

sub create_and_or_update {
   my ($self, $event) = @_;

   my ($job, $job_name, $result, $trans_val);

   try {
      $job = $event->job;
      $job_name = $job->job_name or throw Unspecified, ['job name'];
      $trans_val = $event->transition->value
         or throw Unspecified, ['transition value'];
   }
   catch {
      my $e = $_;
      my $is_exception = blessed $e and $e->can('class');

      $e = exception class => Native, error => "${e}" unless $is_exception;

      $result = ['unknown', 'unknown', $e];
   };

   return $result if $result;

   try   {
      my $job_state  = $self->find_or_create($job);
      my $state_name = $job_state->name->value; # Enumerated type

      $state_name = _workflow()->process_event($state_name, $event);
      $job_state->name($state_name);
      # if ($state_name eq 'starting') {
      $job_state->next_start_time($job->next_start_time($job_state->updated));
      # $job_state->last_start_time($job->last_start_time($job_state->updated));
      # }
      $job_state->update;
      $self->_trigger_update_cascade($event, $job_state);
   }
   catch {
      my $e = $_;
      my $is_exception = blessed $e and $e->can('class');

      $e = exception class => Native, error => "${e}" unless $is_exception;

      $result = [$job_name, $trans_val, $e];
   };

   return $result;
}

=item C<find_by_key>

   $job_state = $self->find_by_key($key, \%options?);

=cut

sub find_by_key {
   my ($self, $state_key, $options) = @_;

   return unless defined $state_key and length $state_key;

   $options //= {};

   return $self->find($state_key, $options) if $state_key =~ m{ \A \d+ \z }mx;

   $options->{prefetch} = 'job';

   return $self->search({ 'me.name' => $state_key }, $options)->single;
}

=item C<find_or_create>

   $job_state = $self->find_or_create($job);

=cut

sub find_or_create {
   my ($self, $job) = @_;

   my $job_state = $self->find($job->id);

   return $job_state if $job_state;

   my $parent_state = 'inactive';

   if ($job->parent_id and $job->id != $job->parent_id) {
      if ($parent_state = $self->find($job->parent_id)) {
         $parent_state = $parent_state->name;
      }
   }

   my $initial_state = 'inactive';

   $initial_state = 'active' if includes $parent_state, $self->initially_active;

   $job_state = $self->create({ job_id => $job->id, name => $initial_state });

   if ($parent_state eq 'running' and !$job->condition and !$job->crontab) {
      my $ev_rs = $self->result_source->schema->resultset('Event');

      $ev_rs->create({ job_id => $job->id, transition => 'start' });
   }

   return $job_state;
}

# Private methods
sub _trigger_update_cascade {
   my ($self, $event, $job_state) = @_;

   my $trans_val = $event->transition->value;
   my $schema    = $self->result_source->schema;
   my $ev_rs     = $schema->resultset('Event');
   my $job_rs    = $schema->resultset('Job');
   my $jc_rs     = $schema->resultset('JobCondition');

   if (my $for_trans = $self->event_propagation->{forward}->{$trans_val}) {
      my $where = { parent_id => $event->job->id };

      for my $job ($job_rs->search($where)->all) {
         $ev_rs->create({ job_id => $job->id, transition => $for_trans });
      }

      if ($for_trans eq 'start') {
         for my $jc ($jc_rs->search({ job_id => $event->job->id })->all) {
            my $options = { job_id => $jc->reverse_id, transition => 'start' };

            $ev_rs->create($options);
         }
      }
   }

   if (my $rev_trans = $self->event_propagation->{reverse}->{$trans_val}) {
      if ($event->job->parent_id) {
         my $options = {
            job_id     => $event->job->parent_id,
            transition => $rev_trans
         };

         $ev_rs->create($options);
      }
   }

   if ($job_state->name eq 'active') {
      my $parent = $event->job->parent_box;

      if (!$parent || $parent->state->name eq 'running') {
         my $options = { job_id => $event->job_id, transition => 'start' };

         $ev_rs->create($options);
      }
   }

   return;
}

my $_workflow_cache;

sub _workflow {
   $_workflow_cache //= App::MCP::Workflow->new; return $_workflow_cache;
}

use namespace::autoclean;

1;

__END__

=back

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Moo>

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

Peter Flanigan, C<< <pjfl@cpan.org> >>

=head1 License and Copyright

Copyright (c) 2025 Peter Flanigan. All rights reserved

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
