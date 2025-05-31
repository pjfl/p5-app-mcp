package App::MCP::Form::State;

use App::MCP::Constants    qw( TRANSITION_ENUM );
use HTML::Forms::Constants qw( FALSE META NUL SPC TRUE );
use App::MCP::Util         qw( trigger_input_handler trigger_output_handler );
use English                qw( -no_match_vars );
use Type::Utils            qw( class_type );
use App::MCP::Workflow;
use Moo;
use HTML::Forms::Moo;

extends 'HTML::Forms::Model::DBIC';
with    'HTML::Forms::Role::Defaults';

has '+name'            => default => 'state-edit';
has '+title'           => default => 'State';
has '+do_form_wrapper' => default => FALSE;
has '+info_message'    => default => 'Change the current job state';
has '+is_html5'        => default => TRUE;

has '_workflow' =>
   is      => 'lazy',
   isa     => class_type('Class::Workflow'),
   default => sub { App::MCP::Workflow->new };

has_field 'job_name' => type => 'Display';

has_field 'state_name' => type => 'Display', label => 'Current State';

has_field 'condition' => type => 'Display';

has_field 'crontab' => type => 'Display';

has_field 'command' => type => 'Display';

has_field 'host' => type => 'Display';

has_field 'signal' => type => 'Select';

sub options_signal {
   my $self        = shift;
   my $name        = $self->form->item->state->name;
   my @transitions = $self->form->_workflow->get_state($name)->transitions;

   return [ map { $_, _to_label($_) } sort map { $_->name } @transitions ];
}

has_field 'edit' =>
   type          => 'Button',
   label         => 'Edit',
   value         => 'edit',
   wrapper_class => ['input-button', 'inline'];

has_field 'history' =>
   type          => 'Button',
   label         => 'History',
   value         => 'history',
   wrapper_class => ['input-button', 'inline'];

has_field 'submit' =>
   type          => 'Button',
   wrapper_class => ['input-button', 'inline', 'right'];

after 'after_build_fields' => sub {
   my $self       = shift;
   my $job        = $self->item;
   my $label      = $job->type eq 'job' ? 'Job Name' : 'Box Name';
   my $state_name = $job->state->name;

   $self->field('job_name')->label($label);
   $self->field('state_name')->value($state_name);
   $self->field('state_name')->add_element_class($state_name);

   $self->field('command')->inactive(TRUE) if $job->type eq 'box';
   $self->field('condition')->inactive(TRUE) unless $job->condition;
   $self->field('crontab')->inactive(TRUE) unless $job->crontab;
   $self->field('host')->inactive(TRUE) if $job->type eq 'box';
   return;
};

sub validate {
   my $self = shift;

   return if $self->result->has_errors;

   my $context = $self->context;
   my $signal  = $self->field('signal')->value;
   my $args    = { job_id => $self->item->id, transition => $signal };

   if ($signal ne 'start') {
      my $last_pev = $context->schema->resultset('ProcessedEvent')->search(
         { job_id  => $self->item->id, transition => 'start' },
         { columns => ['runid'], order_by => { -desc => 'created' } }
      )->single;

      $args->{runid} = $last_pev->runid if $last_pev;
   }

   $context->schema->resultset('Event')->create($args);

   my $daemon_pid = $context->config->appclass->env_var('daemon_pid');

   if ($signal ne 'start') { trigger_input_handler $daemon_pid }
   else { trigger_output_handler $daemon_pid }

   return;
}

sub _to_label {
   return join SPC, map { ucfirst } split m{ [_] }mx, shift;
}

use namespace::autoclean -except => META;

1;
