package App::MCP::Form::Job;

use HTML::Forms::Constants qw( FALSE META NUL SPC TRUE );
use HTML::Forms::Types     qw( ArrayRef HashRef Str );
use Moo;
use HTML::Forms::Moo;

extends 'HTML::Forms::Model::DBIC';
with    'HTML::Forms::Role::Defaults';
with    'HTML::Forms::Role::ToggleRequired';
with    'App::MCP::Role::JSONParser';

has '+form_wrapper_class' => default => sub { ['narrow'] };
has '+info_message'       => default => 'Create or edit jobs';
has '+item_class'         => default => 'Job';
has '+name'               => default => 'Job';
has '+title'              => default => 'Create Job';

has 'default_group' => is => 'ro', isa => Str, default => 'edit';

has '_groups' =>
   is      => 'lazy',
   isa     => ArrayRef,
   default => sub { [shift->context->model('Role')->all] };

has '_group_map' =>
   is      => 'lazy',
   isa     => HashRef,
   default => sub {
      return { map { $_->role_name => $_->id } @{shift->_groups} };
   };

has '_icons' =>
   is      => 'lazy',
   isa     => Str,
   default => sub { shift->context->icons_uri->as_string };

has_field 'job_name' => required => TRUE;

has_field '_g1' => type => 'Group';

has_field 'type' =>
   type          => 'Select',
   html_name     => 'job_type',
   input_param   => 'job_type',
   field_group   => '_g1',
   toggle        => { job => [qw(command directory _g3 _g4)] },
   toggle_event  => 'change',
   options       => [
      { label => 'Job', value => 'job' },
      { label => 'Box', value => 'box' },
   ];

has_field 'parent_id' => type => 'Hidden', field_group => '_g1';

has_field 'parent_name' =>
   type        => 'SelectOne',
   display_as  => '...',
   label       => 'Parent Box',
   field_group => '_g1',
   noupdate    => TRUE,
   title       => 'Select Parent';

has_field '_g2' => type => 'Group';

has_field 'owner' => type => 'Hidden', field_group => '_g2';

has_field 'owner_name' =>
   type          => 'Text',
   field_group   => '_g2',
   label         => 'Owner',
   noupdate      => TRUE,
   readonly      => TRUE,
   size          => 8,
   value         => 'owner_rel.user_name';

has_field 'group_rel' =>
   type        => 'Select',
   field_group => '_g2',
   label       => 'Group',
   value       => 'group_rel.role_name';

sub options_group_rel {
   my $self   = shift;
   my $option = sub {
      return { label => ucfirst $_[0]->role_name, value => $_[0]->id };
   };

   return [ map { $option->($_) } @{$self->_groups} ];
}

has_field 'permissions' =>
   type        => 'PosInteger',
   default     => '0750',
   field_group => '_g2',
   size        => 4;

has_field 'condition' =>
   type => 'TextArea',
   cols => 32,
   tags => { nospellcheck => TRUE };

has_field '_g5' => type => 'Group';

has_field 'crontab_min' =>
   label       => 'Minute',
   field_group => '_g5',
   size        => 3;

has_field 'crontab_hour' =>
   label       => 'Hour',
   field_group => '_g5',
   size        => 3;

has_field '_g6' => type => 'Group';

has_field 'crontab_mday' =>
   label       => 'Day of Month',
   field_group => '_g6',
   size        => 3;

has_field 'crontab_mon' =>
   label       => 'Month',
   field_group => '_g6',
   size        => 3;

has_field 'crontab_wday' =>
   label => 'Day of Week',
   size  => 3;

has_field '_g4' =>
   type => 'Group',
   info => 'These fields are not needed if job type is box';

has_field 'user_name' =>
   default       => 'mcp',
   field_group   => '_g4',
   required      => TRUE,
   size          => 8;

has_field 'host' =>
   default     => 'localhost',
   field_group => '_g4',
   required    => TRUE;

has_field 'command' =>
   type     => 'TextArea',
   cols     => 32,
   required => TRUE,
   tags     => { nospellcheck => TRUE };

has_field 'directory' => size => 32;

has_field '_g3' => type => 'Group';

has_field 'expected_rv' =>
   type                => 'PosInteger',
   default             => 0,
   field_group         => '_g3',
   label               => 'Expected RV',
   size                => 3,
   validate_inline     => TRUE,
   validate_when_empty => TRUE;

has_field 'delete_after' =>
   type        => 'Boolean',
   field_group => '_g3';

has_field 'view' =>
   type          => 'Link',
   label         => 'View',
   element_class => ['form-button'],
   wrapper_class => [qw(input-button inline)];

has_field 'submit' => type => 'Button';

after 'after_build_fields' => sub {
   my $self    = shift;
   my $context = $self->context;

   if (my $item = $self->item) {
      my $view = $self->context->uri_for_action('job/view', [$item->id]);

      $self->field('view')->href($view->as_string);
      $self->field('submit')->add_wrapper_class(['inline', 'right']);
      $self->field('type')->disabled(TRUE);
      $self->field('parent_name')->default($item->parent_box->job_name)
         if $item->parent_box;
      $self->field('group_rel')->value($item->group);
      $self->field('owner_name')->default($item->owner_rel->user_name);
   }
   else {
      my $group_id = $self->_group_map->{$self->default_group};

      $self->field('group_rel')->default($group_id);
      $self->field('owner')->default($context->session->id);
      $self->field('owner_name')->default($context->session->username);
      $self->field('view')->inactive(TRUE);
   }

   my $selector = $context->uri_for_action('job/select', [], {});
   my $parent   = $self->field('parent_name');

   $parent->icons($self->_icons);
   $parent->modal($context->config->wcom_resources->{modal});
   $parent->selector_url("${selector}");
   return;
};

before 'update_model' => sub {
   my $self = shift;

   if ($self->item) { $self->field('owner')->value($self->item->owner) }
   else { $self->field('owner')->value($self->context->session->id) }

   if (my $parent_name = $self->field('parent_name')->value) {
      my $rs     = $self->context->model('Job');
      my $parent = $rs->find({ job_name => $parent_name });

      $self->field('parent_id')->value($parent->id) if $parent;
   }

   my $perms = $self->field('permissions');

   $perms->value(oct $perms->value);

   return;
};

use namespace::autoclean -except => META;

1;
