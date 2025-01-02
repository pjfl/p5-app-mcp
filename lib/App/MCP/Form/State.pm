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

has_field 'signal' =>
   type => 'Select',
   options => [[qw(start stop hold)]];

has_field 'submit' => type => 'Button';

after 'after_build_fields' => sub {
   my $self = shift;

   $self->field('state_name')->value($self->item->state->name);

   return;
};

sub validate {
   my $self = shift;

   return if $self->result->has_errors;


   return;
}

use namespace::autoclean -except => META;

1;
