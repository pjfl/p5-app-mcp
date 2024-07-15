package App::MCP::Schema::Schedule::Result::JobState;

use strictures;
use parent 'App::MCP::Schema::Base';

use App::MCP::Constants qw( STATE_ENUM );
use App::MCP::Util      qw( enumerated_data_type foreign_key_data_type );

my $class  = __PACKAGE__;
my $result = 'App::MCP::Schema::Schedule::Result';

$class->table('job_states');

$class->add_columns(
   job_id    => foreign_key_data_type,
   updated   => { data_type => 'datetime', },
   name      => enumerated_data_type( STATE_ENUM ),
);

$class->set_primary_key('job_id');

$class->belongs_to( job              => "${result}::Job",            'job_id' );
$class->has_many  ( events           => "${result}::Event",          'job_id' );
$class->has_many  ( processed_events => "${result}::ProcessedEvent", 'job_id' );

# Public methods
sub job_name {
   return $_[0]->job->name;
}

sub last_finish {
   my $self  = shift;
   my $event = $self->_last_finish_event;

   return $event ? $event->processed : 'never';
}

sub last_pid {
   my $self  = shift;
   my $event = $self->_last_finish_event;

   return $event ? $event->pid : 'none';
}

sub last_runid {
   my $self  = shift;
   my $event = $self->_last_finish_event;

   return $event ? $event->runid : 'none';
}

sub last_rv {
   my $self  = shift;
   my $event = $self->_last_finish_event;

   return $event ? $event->rv : 'none';
}

sub last_start {
   my $self  = shift;
   my $event = $self->_last_start_event;

   return $event ? $event->created : 'never';
}

# Private methods
sub _last_finish_event {
   my $self = shift;

   return $self->{_last_finish_event} if exists $self->{_last_finish_event};

   # TODO: Use of first?
   return $self->{_last_finish_event} = $self->processed_events->search(
      { transition => 'finish' },
      { order_by   => { -desc => 'runid' } }
   )->first;
}

sub _last_start_event {
   my $self = shift;

   return $self->{_last_start_event} if exists $self->{_last_start_event};

   return $self->{_last_start_event} = $self->processed_events->search(
      { transition => 'start' },
      { order_by   => { -desc => 'runid' } }
   )->first;
}

1;

__END__

=pod

=head1 Name

App::MCP::Schema::Schedule::Result::JobStatus - <One-line description of module's purpose>

=head1 Synopsis

   use App::MCP::Schema::Schedule::Result::JobStatus;
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
