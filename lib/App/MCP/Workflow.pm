package App::MCP::Workflow;

use App::MCP::Constants   qw( EXCEPTION_CLASS FALSE TRUE );
use Scalar::Util          qw( blessed );
use Unexpected::Functions qw( throw catch_class ActiveJobs AutoHold Condition
                              Crontab ExpectedRV Illegal Parent Retry );
use App::MCP::Workflow::Transition;
use Try::Tiny;
use Moo;

extends 'Class::Workflow';

=pod

=head1 Name

App::MCP::Workflow - Finite state automata

=head1 Synopsis

   use App::MCP::Workflow;

=head1 Description

Finite state automata

=head1 Configuration and Environment

Defines no attributes

=head1 Subroutines/Methods

Defines the following methods;

=over 3

=item C<BUILDARGS>

Sets the L<< C<transition_class>|App::MCP::Workflow::Transition >> attribute in
the constructor call

=cut

around 'BUILDARGS' => sub {
   my ($orig, $self, @args) = @_;

   my $attr = $orig->($self, @args);

   $attr->{transition_class} = __PACKAGE__.'::Transition';

   return $attr;
};

=item C<BUILD>

Initialises the workflow object. Defines states and transitions

=cut

# TODO: Que_wait for load average balencing

sub BUILD {
   my $self = shift;

   $self->initial_state('inactive');

   my $active  = [qw(deactivate force_start on_hold start started)];
   my $running = [qw(fail finish kill_job terminate)];
   my $done    = [qw(deactivate activate on_hold)];

   $self->state('active',     transitions => $active);
   $self->state('hold',       transitions => [qw(deactivate off_hold)]);
   $self->state('failed',     transitions => $done);
   $self->state('finished',   transitions => $done);
   $self->state('inactive',   transitions => [qw(activate on_hold)]);
   $self->state('running',    transitions => $running);
   $self->state('starting',   transitions => [qw(fail started)]);
   $self->state('terminated', transitions => $done);

   $self->transition('activate',    to_state   => 'active',
                                    validators => [\&_validate_activate]);
   $self->transition('deactivate',  to_state   => 'inactive');
   $self->transition('fail',        to_state   => 'failed');
   $self->transition('finish',      to_state   => 'finished',
                                    validators => [\&_validate_finish]);
   $self->transition('force_start', to_state   => 'starting');
   $self->transition('kill_job',    to_state   => 'failed');
   $self->transition('off_hold',    to_state   => 'active');
   $self->transition('on_hold',     to_state   => 'hold');
   $self->transition('start',       to_state   => 'starting',
                                    validators => [\&_validate_start]);
   $self->transition('started',     to_state   => 'running');
   $self->transition('terminate',   to_state   => 'terminated');
   return;
}

=item C<process_event>

   $state_name = $self->process_event($state_name, $event);

Applies the C<event>.C<transition> to a workflow instance initialised with the
given C<state_name>

Returns the new C<state_name> if the C<transition> is valid, raises an
exception otherwise

=cut

sub process_event {
   my ($self, $state_name, $event) = @_;

   my $trigger = TRUE;

   while ($trigger) {
      $trigger = FALSE;

      try {
         my $trans_val  = $event->transition->value;
         my $state      = $self->state($state_name);
         my $instance   = $self->new_instance(state => $state);
         my $transition = $instance->state->get_transition($trans_val);

         throw Illegal, [$trans_val, $state_name] unless $transition;

         $instance   = $transition->apply($instance, $event);
         $state_name = $instance->state->name;
      }
      catch_class [
         'Retry' => sub { $trigger = TRUE },
         '*'     => sub { throw $_ },
      ];
   }

   return $state_name;
}

# Private methods
sub _validate_activate {
   my ($self, $instance, $event) = @_;

   if ($event->transition->value ne 'off_hold' && $event->job->auto_hold) {
      $event->transition->set_on_hold;
      throw AutoHold;
   }

   return;
}

sub _validate_finish {
   my ($self, $instance, $event) = @_;

   my $job = $event->job;

   throw ActiveJobs if $job->type eq 'box' && $job->has_active_jobs;

   if ($event->rv > $job->expected_rv) {
      $event->transition->set_fail;
      throw ExpectedRV, [$event->rv, $job->expected_rv];
   }

   return;
}

sub _validate_start {
   my ($self, $instance, $event) = @_;

   my $job    = $event->job;
   my $parent = $job->parent_box;

   throw Parent    if $parent && $parent->state->name ne 'running';
   throw Crontab   unless $job->should_start_now;
   throw Condition unless $job->start_condition;

   return;
}

use namespace::autoclean;

1;

__END__

=back

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Class::Workflow>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module.  Please report problems to the address
below.  Patches are welcome

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
