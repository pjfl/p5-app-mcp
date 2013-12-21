# @(#)$Ident: Workflow.pm 2013-11-19 23:17 pjf ;

package App::MCP::Workflow;

use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.3.%d', q$Rev: 10 $ =~ /\d+/gmx );

use App::MCP::Constants;
use App::MCP::Workflow::Transition;
use Class::Usul::Functions  qw( throw );
use Moo;
use Scalar::Util            qw( blessed );
use TryCatch;
use Unexpected::Functions   qw( Condition Crontab Illegal Retry );

extends q(Class::Workflow);

around 'BUILDARGS' => sub {
   my ($next, $self, @args) = @_; my $attr = $self->$next( @args );

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
         my ($self, $instance, $event) = @_; my $job = $event->job_rel;

         $event->rv <= $job->expected_rv and return;
         $event->transition->set_fail;
         throw error => 'Rv [_1] greater than expected [_2]',
               args  => [ $event->rv, $job->expected_rv ], class => Retry;
      }, ] );

   $self->transition( 'off_hold',  to_state => 'active' );

   $self->transition( 'on_hold',   to_state => 'hold' );

   $self->transition( 'start',     to_state => 'starting', validators => [
      sub {
         my ($self, $instance, $event) = @_; my $job = $event->job_rel;

         $job->should_start_now
            or throw error => 'Not at this time', class => Crontab;

         $job->eval_condition
            or throw error => 'Condition not true', class => Condition;

         return;
      }, ] );

   $self->transition( 'started',   to_state => 'running' );

   $self->transition( 'terminate', to_state => 'terminated' );
   return;
}

sub process_event {
   my ($self, $state_name, $event) = @_;

 RETRY:
   try {
      my $ev_t       = $event->transition;
      my $state      = $self->state( $state_name );
      my $instance   = $self->new_instance( state => $state );
      my $transition = $instance->state->get_transition( $ev_t->value )
         or throw error => 'Transition [_1] from state [_2] illegal',
                  args  => [ $ev_t->value, $state_name ], class => Illegal;

      $instance   = $transition->apply( $instance, $event );
      $state_name = $instance->state->name;
   }
   catch ($e) {
      my $class = blessed $e && $e->can( 'class' ) ? $e->class : undef;

      $class and $class eq Retry and goto RETRY; throw $e;
   }

   return $state_name;
}

1;

__END__

=pod

=head1 Name

App::MCP::Workflow - <One-line description of module's purpose>

=head1 Version

This documents version v0.3.$Rev: 10 $

=head1 Synopsis

   use App::MCP::Workflow;
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

Copyright (c) 2013 Peter Flanigan. All rights reserved

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
