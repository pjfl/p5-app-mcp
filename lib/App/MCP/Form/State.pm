package App::MCP::Form::State;

use App::MCP::Constants    qw( TRANSITION_ENUM );
use HTML::Forms::Constants qw( META  );
use App::MCP::Util         qw( trigger_input_handler trigger_output_handler );
use English                qw( -no_match_vars );
use Type::Utils            qw( class_type );
use App::MCP::Workflow;
use Moo;
use HTML::Forms::Moo;

extends 'HTML::Forms';
with    'HTML::Forms::Role::Defaults';

has '+do_form_wrapper' => default => FALSE;
has '+info_message'    => default => 'Change the current job state';
has '+is_html5'        => default => TRUE;
has '+name'            => default => 'state-edit';
has '+title'           => default => 'State';

has '_workflow' =>
   is      => 'lazy',
   isa     => class_type('Class::Workflow'),
   default => sub { App::MCP::Workflow->new };

has_field 'job_name' => type => 'Display';

has_field 'state_name' =>
   type          => 'Display',
   label         => 'Current State',
   element_class => ['job-state tile'];

has_field 'condition' => type => 'Display', element_class => ['breaking-text'];

has_field 'crontab' => type => 'Display', element_class => ['datetime'];

has_field 'host' => type => 'Display';

has_field 'command' => type => 'Display', element_class => ['code'];

has_field 'auto_hold' => type => 'Boolean', disabled => TRUE;

has_field 'delete_after' => type => 'Boolean', disabled => TRUE;

has_field 'signal' => type => 'Select';

sub options_signal {
   my $self        = shift;
   my $name        = $self->form->item->state->name;
   my @transitions = $self->form->_workflow->get_state($name)->transitions;

   return [ map { $_, _to_label($_) } sort map { $_->name } @transitions ];
}

has_field 'submit' =>
   type          => 'Button',
   wrapper_class => ['input-button', 'inline', 'right'];

has_field 'view' =>
   type          => 'Link',
   label         => 'View',
   element_class => ['form-button', 'pageload'],
   wrapper_class => ['input-button', 'inline'];

has_field 'events' =>
   type          => 'Link',
   label         => 'Events',
   element_class => ['form-button', 'pageload'],
   wrapper_class => ['input-button', 'inline'];

after 'after_build_fields' => sub {
   my $self       = shift;
   my $job        = $self->item;
   my $label      = $job->type eq 'job' ? 'Job Name' : 'Box Name';
   my $state_name = $job->state->name;

   $self->add_form_element_class('narrow');

   if ($job->type eq 'box') {
      $self->info_message('Change the current box state');
      $self->field('auto_hold')->value($job->auto_hold);
      $self->field('delete_after')->inactive(TRUE);
   }
   else {
      $self->field('auto_hold')->inactive(TRUE);
      $self->field('delete_after')->value($job->delete_after);
   }

   $self->field('job_name')->label($label);
   $self->field('state_name')->value($state_name);
   $self->field('state_name')->add_element_class($state_name);

   $self->field('command')->inactive(TRUE) if $job->type eq 'box';
   $self->field('condition')->inactive(TRUE) unless $job->condition;
   $self->field('crontab')->inactive(TRUE) unless $job->crontab;
   $self->field('host')->inactive(TRUE) if $job->type eq 'box';

   my $view = $self->context->uri_for_action('job/view', [$job->id]);

   $self->field('view')->href($view->as_string);

   my $events = $self->context->uri_for_action('history/view', [$job->id]);

   $self->field('events')->href($events->as_string);

   return;
};

sub update_model {
   my $self    = shift;
   my $context = $self->context;
   my $signal  = $self->field('signal')->value;
   my $args    = { job_id => $self->item->id, transition => $signal };

   $context->schema->resultset('Event')->create($args);

   if ($signal eq 'start') { trigger_output_handler $context->config }
   else { trigger_input_handler $context->config }

   return;
}

sub _to_label {
   return join SPC, map { ucfirst } split m{ [_] }mx, shift;
}

use namespace::autoclean -except => META;

1;
