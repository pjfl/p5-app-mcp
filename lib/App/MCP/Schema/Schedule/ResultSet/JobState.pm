package App::MCP::Schema::Schedule::ResultSet::JobState;

use App::MCP::Constants    qw( EXCEPTION_CLASS FALSE NUL TRUE );
use Unexpected::Types      qw( ArrayRef HashRef );
use Unexpected::Functions  qw( Unknown );
use Class::Usul::Cmd::Util qw( includes );
use English                qw( -no_match_vars );
use Scalar::Util           qw( blessed );
use Web::Components::Util  qw( exception throw );
use App::MCP::Workflow;
use Try::Tiny;
use Moo;

extends 'DBIx::Class::ResultSet';

has 'event_propagation' =>
   is      => 'ro',
   isa     => HashRef,
   default => sub {
      return {
         'forward' => {
            'activate'   => 'activate',
            'deactivate' => 'deactivate',
            'fail'       => 'start',
            'finish'     => 'start',
            'off_hold'   => 'activate',
            'on_hold'    => 'deactivate',
            'start'      => NUL,
            'started'    => 'start',
            'terminate'  => 'start',
         },
         'reverse' => {
            'activate'   => NUL,
            'deactivate' => NUL,
            'fail'       => 'finish',
            'finish'     => 'finish',
            'off_hold'   => NUL,
            'on_hold'    => NUL,
            'start'      => NUL,
            'started'    => NUL,
            'terminate'  => 'finish',
         }
      };
   };

has 'initially_active' =>
   is      => 'ro',
   isa     => ArrayRef,
   default => sub { [qw(active running starting)] };

# Public methods
sub create_and_or_update {
   my ($self, $event) = @_;

   my $job        = $event->job;
   my $job_state  = $self->find_or_create($job);
   my $state_name = $job_state->name->value;
   my $res;

   try   {
      $state_name = _workflow()->process_event($state_name, $event);
      $job_state->name($state_name);
      $job_state->update;
      $self->_trigger_update_cascade($event);
   }
   catch {
      my $e = $_;

      $e = exception class => Unknown, error => "${e}"
         unless blessed $e and $e->can('class')
         and $e->class ne 'App::MCP::Exception';

      $res = [$job->job_name, $event->transition->value, $e];
   };

   return $res;
}

sub find_by_key {
   my ($self, $state_key, $options) = @_;

   return unless defined $state_key and length $state_key;

   $options //= {};

   return $self->find($state_key, $options) if $state_key =~ m{ \A \d+ \z }mx;

   $options->{prefetch} = 'job';

   return $self->search({ 'me.name' => $state_key }, $options)->single;
}

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

   $initial_state = 'running' if $parent_state eq 'running'
      and !$job->condition
      and !$job->crontab;

   return $self->create({ job_id => $job->id, name => $initial_state });
}

# Private methods
sub _trigger_update_cascade {
   my ($self, $event) = @_;

   my $ev_trans = $event->transition->value;
   my $schema   = $self->result_source->schema;
   my $ev_rs    = $schema->resultset('Event');
   my $job_rs   = $schema->resultset('Job');
   my $jc_rs    = $schema->resultset('JobCondition');

   if (my $for_trans = $self->event_propagation->{forward}->{$ev_trans}) {
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

   if (my $rev_trans = $self->event_propagation->{reverse}->{$ev_trans}) {
      my $options = {
         job_id     => $event->job->parent_id,
         transition => $rev_trans
      };

      $ev_rs->create($options);
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
