package App::MCP::Schema::Schedule::ResultSet::JobState;

use strictures;
use parent 'DBIx::Class::ResultSet';

use App::MCP::Constants;
use App::MCP::Workflow;
use Class::Usul::Functions qw( exception throw );
use DateTime;
use HTTP::Status           qw( HTTP_NOT_FOUND );
use Scalar::Util           qw( blessed );
use Try::Tiny;
use Unexpected::Functions  qw( Unknown );

# Private methods
my $_trigger_update_cascade = sub {
   my ($self, $event) = @_; my $schema = $self->result_source->schema;

   my $ev_rs = $schema->resultset( 'Event' );
   my $jc_rs = $schema->resultset( 'JobCondition' );

   for ($jc_rs->search( { job_id => $event->job_rel->id } )->all) {
      $ev_rs->create( { job_id => $_->reverse_id, transition => 'start' } );
   }

   return;
};

my $_workflow_cache;

my $_workflow = sub {
   $_workflow_cache //= App::MCP::Workflow->new; return $_workflow_cache;
};

# Public methods
sub create_and_or_update {
   my ($self, $event) = @_; my $res;

   my $job        = $event->job_rel;
   my $job_state  = $self->find_or_create( $job );
   my $state_name = $job_state->name->value;

   try   { $state_name = $_workflow->()->process_event( $state_name, $event ) }
   catch {
      my $e = $_; (blessed $e and $e->can( 'class' ))
         or $e = exception class => Unknown, error => $e;

      $res = [ $event->transition->value, $job->name, $e ];
   };

   $res and return $res;
   $job_state->name( $state_name );
   $job_state->updated( DateTime->now );
   $job_state->update;
   $self->$_trigger_update_cascade( $event );
   return;
}

sub find_by_id_or_name {
   my ($self, $arg) = @_; (defined $arg and length $arg) or return;

   my $job_state; $arg =~ m{ \A \d+ \z }mx and $job_state = $self->find( $arg );

   $job_state or $job_state = $self->find_by_name( $arg );

   return $job_state;
}

sub find_by_name {
   my ($self, $job_name) = @_;

   my $job_state = $self->search
      ( { 'job.name' => $job_name }, { join => 'job' } )->single
      or throw error => 'Job [_1] unknown',
               args  => [ $job_name ], rv => HTTP_NOT_FOUND;

   return $job_state;
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

Copyright (c) 2015 Peter Flanigan. All rights reserved

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
