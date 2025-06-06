package App::MCP::Form::Job;

use HTML::Forms::Constants qw( FALSE META NUL TRUE );
use Moo;
use HTML::Forms::Moo;

extends 'HTML::Forms::Model::DBIC';
with    'HTML::Forms::Role::Defaults';
with    'HTML::Forms::Role::ToggleRequired';

has '+name'         => default => 'Job';
has '+title'        => default => 'Job';
has '+info_message' => default => 'Create or edit jobs';
has '+item_class'   => default => 'Job';

has_field 'job_name' => required => TRUE;

has_field 'type' =>
   type        => 'Select',
   html_name   => 'job_type',
   input_param => 'job_type',
   toggle      => { job => ['command'] },
   options     => [
      { label => 'Box', value => 'box' },
      { label => 'Job', value => 'job' }
   ];

has_field 'parent_box' => type => 'Select', label => 'Parent Box';

sub options_parent_box {
   my $self    = shift;
   my $rs      = $self->context->model($self->item_class);
   my $boxes   = [ $rs->search({ type => 'box' })->all ];
   my $option  = sub { { label => $_[0]->job_name, value => $_[0]->id } };
   my $options = [ map { $option->($_) } @{$boxes} ];

   unshift @{$options}, { label => NUL, value => 0 };

   return $options;
}

has_field 'expected_rv' =>
   type    => 'PosInteger',
   default => 0,
   label   => 'Expected RV';

has_field 'delete_after' => type => 'Boolean';

has_field 'host' => default => 'localhost', required => TRUE;

has_field 'user_name' => default => 'mcp', required => TRUE;

has_field 'command' => required => TRUE;

has_field 'crontab_min' => label => 'Minute';

has_field 'crontab_hour' => label => 'Hour';

has_field 'crontab_mday' => label => 'Day of Month';

has_field 'crontab_mon' => label => 'Month';

has_field 'crontab_wday' => label => 'Day of Week';

has_field 'condition';

has_field 'directory';

has_field 'submit' => type => 'Button';

# owner_id     => foreign_key_data_type( 1, 'owner' ),
# group_id     => foreign_key_data_type( 1, 'group' ),
# permissions  => { accessor      => '_permissions',
#                   data_type     => 'smallint',
#                   default_value => 488,
#                   is_nullable   => FALSE, },


after 'after_build_fields' => sub {
   my $self      = shift;
   my $resources = $self->context->config->wcom_resources;
   my $toggle    = $resources->{toggle} . ".toggleFields('job_type')";

   $self->field('type')->element_attr->{javascript} = { onchange => $toggle };

   return;
};

use namespace::autoclean -except => META;

1;
