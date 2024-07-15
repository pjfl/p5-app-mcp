package App::MCP::Workflow;

use App::MCP::Constants    qw( EXCEPTION_CLASS FALSE TRUE );
use Scalar::Util           qw( blessed );
use Unexpected::Functions  qw( throw catch_class Condition Crontab Illegal
                               Retry );
use App::MCP::Workflow::Transition;
use Try::Tiny;
use Moo;

extends 'Class::Workflow';

around 'BUILDARGS' => sub {
   my ($orig, $self, @args) = @_;

   my $attr = $orig->($self, @args);

   $attr->{transition_class} = __PACKAGE__.'::Transition';

   return $attr;
};

sub BUILD {
   my $self = shift;

   $self->initial_state( 'inactive' );

   $self->state( 'active',     transitions => [ qw(on_hold start) ] );

   $self->state( 'hold',       transitions => [ qw(off_hold) ] );

   $self->state( 'failed',     transitions => [ qw(activate) ] );

   $self->state( 'finished',   transitions => [ qw(activate) ] );

   $self->state( 'inactive',   transitions => [ qw(activate) ] );

   $self->state( 'running',    transitions => [ qw(fail finish terminate) ] );

   $self->state( 'starting',   transitions => [ qw(started)  ] );

   $self->state( 'terminated', transitions => [ qw(activate) ] );


   $self->transition( 'activate',  to_state => 'active' );

   $self->transition( 'fail',      to_state => 'failed' );

   $self->transition( 'finish',    to_state => 'finished', validators => [
      sub {
         my ($self, $instance, $event) = @_;

         my $job = $event->job;

         return if $event->rv <= $job->expected_rv;
         $event->transition->set_fail;
         throw Retry, [ $event->rv, $job->expected_rv ];
      }, ] );

   $self->transition( 'off_hold',  to_state => 'active' );

   $self->transition( 'on_hold',   to_state => 'hold' );

   $self->transition( 'start',     to_state => 'starting', validators => [
      sub {
         my ($self, $instance, $event) = @_;

         my $job = $event->job;

         throw Crontab   unless $job->should_start_now;
         throw Condition unless $job->eval_condition;

         return;
      }, ] );

   $self->transition( 'started',   to_state => 'running' );

   $self->transition( 'terminate', to_state => 'terminated' );
   return;
}

sub process_event {
   my ($self, $state_name, $event) = @_;

   my $trigger = TRUE;

   while ($trigger) {
      $trigger = FALSE;

      try {
         my $ev_t       = $event->transition;
         my $state      = $self->state($state_name);
         my $instance   = $self->new_instance(state => $state);
         my $transition = $instance->state->get_transition($ev_t->value)
            or throw Illegal, [$ev_t->value, $state_name];

         $instance   = $transition->apply($instance, $event);
         $state_name = $instance->state->name;
      }
      catch_class [ Retry => sub { $trigger = TRUE } ];
   }

   return $state_name;
}

use namespace::autoclean;

1;

__END__

=pod

=head1 Name

App::MCP::Workflow - <One-line description of module's purpose>

=head1 Synopsis

   use App::MCP::Workflow;
   # Brief but working code examples

=head1 Description

=head1 Configuration and Environment

=head1 Subroutines/Methods

=head1 Diagnostics

=head1 Dependencies

=over 3

=item L<Class::Workflow>

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
