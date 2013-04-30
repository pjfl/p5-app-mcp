# @(#)$Ident: Workflow.pm 2013-04-30 23:36 pjf ;

package App::MCP::Workflow;

use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 2 $ =~ /\d+/gmx );

use Class::Usul::Moose;
use CatalystX::Usul::Constants;
use CatalystX::Usul::Functions qw(throw);
use App::MCP::Workflow::Transition;
use TryCatch;

extends qw(Class::Workflow);

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
               args  => [ $event->rv, $job->expected_rv ], class => 'Retry';
      }, ] );

   $self->transition( 'off_hold',  to_state => 'active' );

   $self->transition( 'on_hold',   to_state => 'hold' );

   $self->transition( 'start',     to_state => 'starting', validators => [
      sub {
         my ($self, $instance, $event) = @_; my $job = $event->job_rel;

         $job->condition or $job->crontab or return;

         my $job_rs = $job->result_source->resultset;

         $job->crontab and ($job_rs->should_start_now( $job )
            or throw error => 'Not at this time', class => 'Crontab');

         $job->condition and ($job_rs->eval_condition( $job )->[ 0 ]
            or throw error => 'Condition not true', class => 'Condition');

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
                  args  => [ $ev_t->value, $state_name ], class => 'Illegal';

      $instance   = $transition->apply( $instance, $event );
      $state_name = $instance->state->name;
   }
   catch ($e) {
      my $class = blessed $e && $e->can( 'class' ) ? $e->class : 'Unknown';

      $class eq 'Retry' and goto RETRY; $class ne 'Unknown' and throw $e;

      throw error => $e, class => $class;
   }

   return $state_name;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=head1 Name

App::MCP::Workflow - <One-line description of module's purpose>

=head1 Version

This documents version v0.1.$Revision: 2 $

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
