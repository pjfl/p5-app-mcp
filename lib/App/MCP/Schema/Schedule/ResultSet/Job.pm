package App::MCP::Schema::Schedule::ResultSet::Job;

use App::MCP::Constants   qw( EXCEPTION_CLASS FALSE NUL SEPARATOR TRUE );
use HTTP::Status          qw( HTTP_NOT_FOUND );
use App::MCP::Util        qw( strip_namespace );
use HTML::Forms::Util     qw( json_bool );
use Unexpected::Functions qw( throw Unspecified UnknownJob UnknownUser );
use Moo;

extends 'DBIx::Class::ResultSet';

=pod

=head1 Name

App::MCP::Schema::Schedule::ResultSet::Job - Custom collection class

=head1 Synopsis

   use Moo;

   with 'App::MCP::Role::Schema';

   my $rs = $self->schema->resultset('Job');

=head1 Description

Custom collection class

=head1 Configuration and Environment

Defines no attributes

=head1 Subroutines/Methods

Defines the following methods;

=over 3

=item C<assert_executable>

   $job = $self->assert_executable($job_key, $user);

Finds the job using the C<job_key> and tests to see if it is executable by
the given C<user>

Returns the job if the user can execute it, raises an exception otherwise

=cut

sub assert_executable {
   my ($self, $job_key, $user) = @_;

   my $job = $self->find_by_key($job_key);

   throw 'Job [_1] execute permission denied to [_2]',
      [$job->job_name, $user->user_name] unless $job->is_executable_by($user);

   return $job;
}

=item C<create>

   $job = $self->create(\%column_data);

Creates a new persisted job object using the C<column_data> provided

Returns the new L<job object|App::MCP::Schema::Schedule::Result::Job>

=cut

sub create {
   my ($self, $col_data) = @_;

   my $prefix      = NUL;
   my $sep         = SEPARATOR;
   my $job_name    = delete $col_data->{job_name};
   my $parent_name = delete $col_data->{parent_name};

   if (defined $parent_name and length $parent_name) {
      $prefix = (not $col_data->{type} or $col_data->{type} eq 'job')
              ? $parent_name . $sep
              : ((split m{ $sep }mx, $parent_name)[0]) . $sep;
   }

   $col_data->{job_name} = defined $job_name ? $prefix . $job_name : NUL;

   if ($parent_name) {
      $col_data->{parent_id}
         = $self->writable_box_id_by_name($parent_name, $col_data->{owner_id});
   }

   return $self->next::method($col_data);
}

=item C<done>

   $bool = $self->done($job_key);

=cut

sub done {
   my ($self, $key) = @_;

   my $job_state = $self->_get_job_state($key);

   return TRUE if $job_state eq 'failed';
   return TRUE if $job_state eq 'finished';
   return TRUE if $job_state eq 'terminated';
   return FALSE;
}

=item C<dump>

   $array_ref = $self->dump($job_pattern);

=cut

sub dump {
   my ($self, $job_spec) = @_;

   my @jobs;

   my $rs = $self->search({ 'me.job_name' => { like => $job_spec } }, {
      order_by     => [\q{me.parent_id NULLS FIRST}, 'me.id'],
      result_class => 'DBIx::Class::ResultClass::HashRefInflator',
      prefetch     => ['owner_rel', 'group_rel', 'parent_box'],
   });

   for my $job (grep { length $_->{job_name} } $rs->all) {
      $job->{auto_hold}    = json_bool $job->{auto_hold};
      $job->{delete_after} = json_bool $job->{delete_after};
      $job->{group}        = $job->{group_rel}->{role_name};
      $job->{job_name}     = strip_namespace $job->{job_name};
      $job->{owner}        = $job->{owner_rel}->{user_name};
      $job->{parent_name}  = strip_namespace $job->{parent_box}->{job_name};

      delete $job->{dependencies};
      delete $job->{group_id};
      delete $job->{group_rel};
      delete $job->{owner_id};
      delete $job->{owner_rel};
      delete $job->{parent_id};
      delete $job->{parent_box};
      delete $job->{parent_path};
      delete $job->{path_depth};

      push @jobs, $job;
   }

   return \@jobs;
}

=item C<find_by_key>

   $job = $self->find_by_key($job_key, \%options?);

Finds an existing job object using the supplied C<job_key>. The C<job_key> can
be either a C<job_id> or a C<job_name>

Returns the job object if it exists, returns undefined otherwise

=cut

sub find_by_key {
   my ($self, $job_key, $options) = @_;

   return unless defined $job_key and length $job_key;

   my $job; $options //= {};

   if ($job_key =~ m{ \A \d+ \z }mx) { $job = $self->find($job_key, $options) }
   else { $job = $self->search({'me.job_name' => $job_key}, $options)->single }

   return $job;
}

=item C<finished>

   $bool = $self->finished($job_key);

=cut

sub finished {
   my ($self, $key) = @_;

   return $self->_get_job_state($key) eq 'finished' ? TRUE : FALSE;
}

=item C<job_id_by_name>

   $job_id = $self->job_id_by_name($job_key);

=cut

sub job_id_by_name {
   my ($self, $job_key) = @_;

   my $job = $self->find_by_key($job_key, { columns => ['id'] });

   return $job ? $job->id : undef;
}

=item C<load>

   $count = $self->load(\%user_details, \@jobs?);

=cut

sub load {
   my ($self, $auth, $jobs) = @_;

   my $count = 0;

   for my $job (@{ $jobs // [] }) {
      # TODO: Lookup job->{owner/group}->id
      my $owner_id = $auth->{user}->id;
      my $group_id = $auth->{role}->id;

      $job->{owner_id} = $owner_id;
      $job->{group_id} = $group_id;
      $self->create($job);
      $count++;
   }

   return $count;
}

=item C<predicates>

   $array_ref = $self->predicates;

=cut

# TODO: Predicates should take a look back time duration value
# TODO: Globals condition: success(BACKUP) AND value(TODAY)=Friday
sub predicates {
   return [ qw(done finished running terminated) ];
}

=item C<running>

   $bool = $self->running($job_key);

=cut

sub running {
   my ($self, $key) = @_;

   return $self->_get_job_state($key) eq 'running' ? TRUE : FALSE;
}

=item C<should_start_now>

   $rs = $self->should_start_now;

Search for jobs in the C<active> state that have C<crontab> entries.
If the C<crontab> and C<condition> are true (if the job has one) then include
the job in the result

Returns a list of qualifying jobs. Objects are only partially inflated

=cut

sub should_start_now {
   my $self     = shift;
   my $now      = time;
   my $columns  = [ qw(condition crontab id state.name state.next_start_time) ];
   my $prefetch = [ 'state', { parent_box => 'state' } ];
   my $options  = { columns => $columns, prefetch => $prefetch };
   my $where    = {
      'state.name'   => 'active',
      'state_2.name' => 'running',
      'me.crontab'   => { '!=' => NUL },
      'state.next_start_time' => { '<' => $now },
   };
   my @jobs;

   for my $job ($self->search($where, $options)->all) {
       next unless $job->condition_start_now;

       push @jobs, $job;
   }

   return @jobs;
}

=item C<terminated>

   $bool = $self->terminated($job_key);

=cut

sub terminated {
   my ($self, $key) = @_;

   return $self->_get_job_state($key) eq 'terminated' ? TRUE : FALSE;
}

=item C<writable_box_id_by_name>

   $job_id = $self->writable_box_id_by_name($job_key, $user_key?);

=cut

sub writable_box_id_by_name {
   my ($self, $job_key, $user_key) = @_;

   $user_key // 0;

   my $job = $self->find_by_key($job_key);

   throw 'Job [_1] is not a box', [$job->job_name] unless $job->type eq 'box';

   my $user_rs = $self->result_source->schema->resultset('User');
   my $user    = $user_rs->find_by_key($user_key, { prefetch => 'profile' });

   throw UnknownUser, [$user_key] unless $user;
   throw 'Box [_1] write permission denied to [_2]',
      [$job->job_name, $user->user_name] unless $job->is_writable_by($user);

   return $job->id;
}

# Private methods
sub _get_job_state {
   my ($self, $job_key) = @_;

   my $job = $self->find_by_key($job_key, { prefetch => 'state' });

   return 'unknown' unless $job;

   return $job->state ? $job->state->name : 'inactive';
}

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
