package App::MCP::Form::State;

use HTML::Forms::Constants qw( FALSE META NUL TRUE );
use Moo;
use HTML::Forms::Moo;

extends 'HTML::Forms::Model::DBIC';
with    'HTML::Forms::Role::Defaults';

has '+name'            => default => 'state-edit';
has '+title'           => default => 'State';
has '+do_form_wrapper' => default => FALSE;
has '+info_message'    => default => 'Change the current job state';
has '+is_html5'        => default => TRUE;

has_field 'job_name' => type => 'Display';

has_field 'state_name' => type => 'Display', label => 'Current State';

has_field 'condition' => type => 'Display';

has_field 'crontab' => type => 'Display';

has_field 'command' => type => 'Display';

has_field 'host' => type => 'Display';

has_field 'signal' =>
   type => 'Select',
   options => [[qw(start stop hold)]];

has_field 'edit' =>
   type          => 'Button',
   label         => 'Edit',
   value         => 'edit',
   wrapper_class => ['input-button', 'inline'];

has_field 'submit' =>
   type          => 'Button',
   wrapper_class => ['input-button', 'inline', 'right'];

after 'after_build_fields' => sub {
   my $self  = shift;
   my $job   = $self->item;
   my $label = $job->type eq 'job' ? 'Job Name' : 'Box Name';

   $self->field('job_name')->label($label);
   $self->field('state_name')->value($job->state->name);

   $self->field('command')->inactive(TRUE) if $job->type eq 'box';
   $self->field('condition')->inactive(TRUE) unless $job->condition;
   $self->field('crontab')->inactive(TRUE) unless $job->crontab;
   $self->field('host')->inactive(TRUE) if $job->type eq 'box';
   return;
};

sub validate {
   my $self = shift;
   my $context = $self->context;

   return if $self->result->has_errors;

   return;
}

use namespace::autoclean -except => META;

1;
