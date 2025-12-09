package App::MCP::Form::Job;

use HTML::Forms::Constants qw( FALSE META NUL SPC TRUE );
use Moo;
use HTML::Forms::Moo;

extends 'HTML::Forms::Model::DBIC';
with    'HTML::Forms::Role::Defaults';
with    'HTML::Forms::Role::ToggleRequired';

has '+name'               => default => 'Job';
has '+info_message'       => default => 'Create or edit jobs';
has '+item_class'         => default => 'Job';
has '+form_element_class' => default => sub { ['narrow'] };
has '+title'              => default => 'Create Job';

has_field 'job_name' => required => TRUE;

has_field '_g1' => type => 'Group';

has_field 'type' =>
   type          => 'Select',
   html_name     => 'job_type',
   input_param   => 'job_type',
   field_group   => '_g1',
   toggle        => { job => [qw(command directory _g2 _g3)] },
   toggle_event  => 'change',
   options       => [
      { label => 'Job', value => 'job' },
      { label => 'Box', value => 'box' },
   ];

has_field 'parent_box' =>
   type        => 'Select',
   field_group => '_g1',
   label       => 'Parent Box';

sub options_parent_box {
   my $self    = shift;
   my $rs      = $self->context->model($self->item_class);
   my $boxes   = [ $rs->search({ type => 'box' })->all ];
   my $option  = sub { { label => $_[0]->job_name, value => $_[0]->id } };
   my $options = [
      map { $option->($_) } sort { $a->job_name cmp $b->job_name } @{$boxes}
   ];

   unshift @{$options}, { label => NUL, value => 0 };

   return $options;
}

has_field '_g2' =>
   type => 'Group',
   info => 'These fields are not needed if job type is box';

has_field 'expected_rv' =>
   type                => 'PosInteger',
   default             => 0,
   field_group         => '_g2',
   label               => 'Expected RV',
   size                => 3,
   validate_inline     => TRUE,
   validate_when_empty => TRUE;

has_field 'delete_after' =>
   type        => 'Boolean',
   field_group => '_g2';

has_field '_g3' => type => 'Group';

has_field 'user_name' =>
   default       => 'mcp',
   field_group   => '_g3',
   required      => TRUE,
   size          => 10;

has_field 'host' =>
   default     => 'localhost',
   field_group => '_g3',
   required    => TRUE;

has_field 'command' =>
   type     => 'TextArea',
   cols     => 38,
   required => TRUE,
   tags     => { nospellcheck => TRUE };

has_field 'directory' => size => 36;

has_field 'condition' => size => 36;

has_field '_g4' => type => 'Group';

has_field 'crontab_min' =>
   label       => 'Minute',
   field_group => '_g4',
   size        => 3;

has_field 'crontab_hour' =>
   label       => 'Hour',
   field_group => '_g4',
   size        => 3;

has_field '_g5' => type => 'Group';

has_field 'crontab_mday' =>
   label       => 'Day of Month',
   field_group => '_g5',
   size        => 3;

has_field 'crontab_mon' =>
   label       => 'Month',
   field_group => '_g5',
   size        => 3;

has_field 'crontab_wday' =>
   label => 'Day of Week',
   size  => 3;

has_field 'view' =>
   type          => 'Link',
   label         => 'View',
   element_class => ['form-button'],
   wrapper_class => [qw(input-button inline)];

has_field 'submit' => type => 'Button';

# owner_id     => foreign_key_data_type( 1, 'owner' ),
# group_id     => foreign_key_data_type( 1, 'group' ),
# permissions  => { accessor      => '_permissions',
#                   data_type     => 'smallint',
#                   default_value => 488,
#                   is_nullable   => FALSE, },

after 'after_build_fields' => sub {
   my $self = shift;

   if ($self->item) {
      my $view = $self->context->uri_for_action('job/view', [$self->item->id]);

      $self->field('view')->href($view->as_string);
      $self->field('submit')->add_wrapper_class(['inline', 'right']);
   }
   else { $self->field('view')->inactive(TRUE) }

   return;
};

use namespace::autoclean -except => META;

1;
