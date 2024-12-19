package App::MCP::Schema::Schedule::ResultSet::Job;

use App::MCP::Constants   qw( EXCEPTION_CLASS FALSE NUL SEPARATOR TRUE );
use HTTP::Status          qw( HTTP_NOT_FOUND );
use App::MCP::Util        qw( strip_parent_name );
use Unexpected::Functions qw( throw Unspecified UnknownJob UnknownUser );
use Moo;

extends 'DBIx::Class::ResultSet';

# Public methods
sub assert_executable {
   my ($self, $job_key, $user) = @_;

   my $job = $self->find_by_key($job_key);

   throw 'Job [_1] execute permission denied to [_2]',
      [$job->job_name, $user->user_name]
      unless $job->is_executable_by($user->id);

   return $job;
}

sub create {
   my ($self, $col_data) = @_;

   my $prefix      = NUL;
   my $sep         = SEPARATOR;
   my $job_name    = delete $col_data->{job_name};
   my $parent_name = delete $col_data->{parent_name};

   if (defined $parent_name and length $parent_name) {
      $prefix = (not $col_data->{type} or $col_data->{type} eq 'job')
              ? $parent_name.$sep
              : ((split m{ $sep }mx, $parent_name)[0]).$sep;
   }

   $col_data->{job_name} = defined $job_name ? $prefix.$job_name : NUL;

   if ($parent_name) {
      $col_data->{parent_id}
         = $self->writable_box_id_by_name($parent_name, $col_data->{owner_id});
   }

   $col_data->{parent_id} //= 1;

   return $self->next::method($col_data);
}

sub dump {
   my ($self, $job_spec) = @_;

   my $index = {};
   my @jobs;

   my $rs = $self->search({ 'me.job_name' => { like => $job_spec } }, {
      order_by     => 'id',
      result_class => 'DBIx::Class::ResultClass::HashRefInflator',
   });

   for my $job ($rs->all) {
      delete $job->{group_id};
      delete $job->{owner_id};
      delete $job->{parent_path};
      $index->{ delete $job->{id} } = $job->{job_name};

      my $parent_id = delete $job->{parent_id};

      $job->{parent_name} = $index->{$parent_id} if $parent_id;

      if (length $job->{job_name}) {
         $job->{job_name} = strip_parent_name $job->{job_name};
         push @jobs, $job;
      }
   }

   return \@jobs;
}

sub find_by_key {
   my ($self, $job_key, $options) = @_;

   return unless defined $job_key and length $job_key;

   my $job; $options //= {};

   if ($job_key =~ m{ \A \d+ \z }mx) { $job = $self->find($job_key, $options) }
   else { $job = $self->search({'me.job_name' => $job_key}, $options)->single }

   return $job;
}

sub finished {
   return $_[0]->_get_job_state($_[1]) eq 'finished' ? TRUE : FALSE;
}

sub writable_box_id_by_name {
   my ($self, $job_key, $user_key) = @_;

   my $job = $self->find_by_key($job_key);

   throw 'Job [_1] is not a box', [$job->job_name] unless $job->type eq 'box';

   my $user_rs = $self->result_source->schema->resultset('User');
   my $user    = $user_rs->find_by_key($user_key // 0);

   throw UnknownUser, [$user_key] unless $user;
   throw 'Box [_1] write permission denied to [_1]',
      [$job->job_name, $user->user_name] unless $job->is_writable_by($user->id);

   return $job->id;
}

sub job_id_by_name {
   my ($self, $job_key) = @_;

   my $job = $self->find_by_key($job_key, { columns => ['id'] });

   return $job ? $job->id : undef;
}

sub load {
   my ($self, $auth, $jobs) = @_;

   my $count = 0;

   for my $job (@{ $jobs // [] }) {
      $job->{owner_id} = $auth->{user}->id;
      $job->{group_id} = $auth->{role}->id;
      $self->create($job);
      $count++;
   }

   return $count;
}

sub predicates {
   return [ qw( finished running terminated ) ];
}

sub running {
   return $_[0]->_get_job_state($_[1]) eq 'running' ? TRUE : FALSE;
}

sub terminated {
   return $_[0]->_get_job_state($_[1]) eq 'terminated' ? TRUE : FALSE;
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

=pod

=head1 Name

App::MCP::Schema::Schedule::ResultSet::Job - <One-line description of module's purpose>

=head1 Synopsis

   use App::MCP::Schema::Schedule::ResultSet::Job;
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

Copyright (c) 2024 Peter Flanigan. All rights reserved

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
