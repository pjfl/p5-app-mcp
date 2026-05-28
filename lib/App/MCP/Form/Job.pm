package App::MCP::Form::Job;

use utf8;

use HTML::Forms::Constants qw( FALSE META NUL SPC TRUE );
use HTML::Forms::Types     qw( ArrayRef HashRef Int Object Str Undef );
use Class::Usul::Cmd::Util qw( includes );
use Moo;
use HTML::Forms::Moo;

extends 'HTML::Forms::Model::DBIC';
with    'HTML::Forms::Role::Defaults';
with    'HTML::Forms::Role::ToggleRequired';
with    'App::MCP::Role::JSONParser';

has '+form_wrapper_class' => default => sub { ['narrow'] };
has '+item_class'         => default => 'Job';
has '+name'               => default => 'Job';
has '+title'              => default => 'Create Job';

has 'clone' => is => 'ro', isa => Object|Undef;

has 'default_group' => is => 'ro', isa => Str, default => 'batch';

has 'min_job_name_len' => is => 'ro', isa => Int, default => 3;

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

has_field 'job_name' =>
   required        => TRUE,
   title           => 'Job names must be unique',
   validate_inline => TRUE;

sub validate_job_name {
   my $self = shift;
   my $name = $self->field('job_name');

   $name->add_error("Job name '[_1]' too short", $name->value || '<empty>')
      if length $name->value < $self->min_job_name_len;

   $name->add_error("Job name '[_1]' not unique", $name->value || '<empty>')
      if !$self->item_id && $self->resultset->find({ job_name => $name->value});

   return;
}

has_field 'description' => type => 'TextArea', cols => 32;

has_field '_box_properties' => type => 'Group';

has_field 'type' =>
   type         => 'Select',
   default      => 'job',
   html_name    => 'job_type',
   input_param  => 'job_type',
   field_group  => '_box_properties',
   toggle       => { job => [qw(_box_group)] },
   toggle_event => 'change',
   options      => [
      { label => 'Job', value => 'job' },
      { label => 'Box', value => 'box' },
   ];

has_field 'parent_id' =>
   type                => 'Hidden',
   validate_when_empty => FALSE,
   field_group         => '_box_properties';

has_field 'parent_name' =>
   type        => 'SelectOne',
   display_as  => '…',
   label       => 'Parent Box',
   field_group => '_box_properties',
   noupdate    => TRUE,
   title       => 'Select the parent box';

has_field '_ownership' => type => 'Group';

has_field 'owner' => type => 'Hidden', field_group => '_ownership';

has_field 'owner_name' =>
   type        => 'Text',
   field_group => '_ownership',
   label       => 'Owner',
   noupdate    => TRUE,
   readonly    => TRUE,
   size        => 8,
   value       => 'owner_rel.user_name',
   title       => 'User owner of the job';

has_field 'group_rel' =>
   type        => 'Select',
   field_group => '_ownership',
   label       => 'Group',
   value       => 'group_rel.role_name',
   title       => 'Group owner of the job';

sub options_group_rel {
   my $self       = shift;
   my $get_option = sub {
      my $self   = shift;
      my $option = { label => ucfirst $self->role_name, value => $self->id };

      $option->{label} = 'MCP' if $self->role_name eq 'mcp';

      return $option;
   };

   return [
      map  { $get_option->($_) }
      grep { !includes $_->role_name, [qw(admin edit view)] }
      @{$self->_groups}
   ];
}

has_field 'permissions' =>
   type        => 'Permission',
   default     => 488,
   display_as  => '±',
   field_group => '_ownership',
   title       => 'Select permissions';

has_field 'condition' =>
   type              => 'TextArea',
   cols              => 32,
   no_value_if_empty => TRUE,
   tags              => { nospellcheck => TRUE },
   title             => 'Run the command when this condition evaluates to true';

has_field '_crontab_hour_min' => type => 'Group';

has_field 'crontab_min' =>
   label       => 'Minute',
   field_group => '_crontab_hour_min',
   size        => 3,
   title       => "Comma separated list. Digits 0-59 or '*'";

has_field 'crontab_hour' =>
   label       => 'Hour',
   field_group => '_crontab_hour_min',
   size        => 3,
   title       => "Comma separated list. Digits 0-23 or '*'";

has_field '_crontab_days' => type => 'Group';

has_field 'crontab_mday' =>
   label       => 'Day of Month',
   field_group => '_crontab_days',
   size        => 3,
   title       => "Comma separated list. Digits 1-31 or '*'";

has_field 'crontab_mon' =>
   label       => 'Month',
   field_group => '_crontab_days',
   size        => 3,
   title       => "Comma separated list. Digits 1-12 or names or '*'";

has_field 'crontab_wday' =>
   label       => 'Day of Week',
   field_group => '_crontab_days',
   size        => 3,
   title       => "Comma separated list. Digits 0-7 or names or '*'. " .
                  "Zero is Sunday";

has_field '_runtime_properties' => type => 'Group';

has_field 'max_runtime' =>
   type        => 'Integer',
   default     => 0,
   field_group => '_runtime_properties',
   label       => 'Max. Runtime',
   size        => 6,
   title       => 'Maximum job run time in seconds';

has_field 'load_limit' =>
   type        => 'Float',
   default     => 0,
   field_group => '_runtime_properties',
   label       => 'Load Limit',
   size        => 3,
   title       => 'Load average must be below this number before ' .
                  'the job starts';

has_field 'auto_hold' =>
   type        => 'Boolean',
   field_group => '_runtime_properties',
   title       => 'When activated automatically go on hold';

has_field '_box_group' => type => 'Group', wrapper_class => ['vertical'];

has_field '_location' =>
   type        => 'Group',
   field_group => '_box_group',
   info        => 'These fields are not needed if job type is box';

has_field 'user_name' =>
   default     => 'mcp',
   field_group => '_location',
   required    => TRUE,
   size        => 8,
   title       => 'Execute command as this remote user';

has_field 'host' =>
   default     => 'localhost',
   field_group => '_location',
   required    => TRUE,
   title       => 'Name of host on which to execute the command';

has_field 'directory' =>
   autocomplete => TRUE,
   field_group  => '_box_group',
   size         => 32,
   title        => 'Make this the working directory when executing the command';

has_field 'command' =>
   type        => 'TextArea',
   cols        => 32,
   field_group => '_box_group',
   required    => TRUE,
   tags        => { nospellcheck => TRUE },
   title       => 'Command to execute on the given host';

has_field '_redirect_io' => type => 'Group', field_group => '_box_group';

has_field 'out_file' =>
   field_group => '_redirect_io',
   label       => 'Output File',
   title       => 'Redirect stdout to this file';

has_field 'err_file' =>
   field_group => '_redirect_io',
   label       => 'Error File',
   title       => 'Redirect stderr to this file';

has_field '_job_properties' => type => 'Group', field_group => '_box_group';

has_field 'expected_rv' =>
   type            => 'PosInteger',
   default         => 0,
   field_group     => '_job_properties',
   label           => 'Expected RV',
   size            => 3,
   title           => 'The expected return value of the command. '
                   . 'Higher values trigger an error condition',
   validate_inline => TRUE;

has_field 'nretrys' =>
   type        => 'Integer',
   default     => 0,
   field_group => '_job_properties',
   label       => 'Num. Retrys',
   size        => 2,
   title       => 'How many times to retry if the job fails';

has_field 'delete_after' =>
   type        => 'Boolean',
   field_group => '_job_properties',
   title       => 'If true delete the job definition after completion';

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
      $self->info_message('Edit jobs and boxes');

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
      $self->info_message('Create jobs and boxes');

      my $group_id = $self->_group_map->{$self->default_group};

      $self->field('group_rel')->default($group_id);
      $self->field('owner')->default($context->session->id);
      $self->field('owner_name')->default($context->session->username);
      $self->field('view')->inactive(TRUE);
   }

   my $resources = $context->config->wcom_resources;
   my $selector  = $context->uri_for_action('job/select', [], {});
   my $parent    = $self->field('parent_name');

   $parent->icons($self->_icons);
   $parent->modal($resources->{modal});
   $parent->selector_url("${selector}");

   my $perms = $self->field('permissions');

   $perms->form_util($resources->{form_util});
   $perms->icons($self->_icons);
   $perms->modal($resources->{modal});

   $self->_populate_with_clone if $self->clone;
   return;
};

sub validate {
   my $self = shift;

   if ($self->item) { $self->field('owner')->value($self->item->owner) }
   else { $self->field('owner')->value($self->context->session->id) }

   if (my $parent_name = $self->field('parent_name')->value) {
      my $rs     = $self->context->model('Job');
      my $parent = $rs->find({ job_name => $parent_name });

      $self->field('parent_id')->value($parent->id) if $parent;
   }

   return;
}

# Private methods
sub _populate_with_clone {
   my $self   = shift;
   # TODO: Copy these parent_id group
   my $fields = [qw(description type parent_id owner permissions condition
                 crontab_min crontab_hour crontab_mday crontab_mon
                 crontab_wday auto_hold user_name host command directory
                 out_file err_file expected_rv nretrys delete_after
                 max_runtime load_limit)];

   for my $field_name (@{$fields}) {
      my $value = $self->clone->$field_name();

      $self->field($field_name)->default($value) if defined $value;
   }

   if (my $parent_box = $self->clone->parent_box) {
      $self->field('parent_name')->default($parent_box->job_name);
   }

   $self->field('group_rel')->default($self->clone->group);
   return;
}

use namespace::autoclean -except => META;

1;
