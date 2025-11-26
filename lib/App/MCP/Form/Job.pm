package App::MCP::Form::Job;

use HTML::Forms::Constants qw( FALSE META NUL SPC TRUE );
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
   type          => 'Select',
   html_name     => 'job_type',
   input_param   => 'job_type',
   toggle        => {
      job => [qw(command delete_after directory expected_rv host user_name)]
   },
   toggle_event  => 'change',
   wrapper_class => [qw(input-select inline)],
   options       => [
      { label => 'Job', value => 'job' },
      { label => 'Box', value => 'box' },
   ];

has_field 'parent_box' =>
   type          => 'Select',
   label         => 'Parent Box',
   wrapper_class => [qw(input-select inline shrink)];

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

has_field 'expected_rv' =>
   type                => 'PosInteger',
   default             => 0,
   label               => 'Expected RV',
   size                => 3,
   validate_inline     => TRUE,
   validate_when_empty => TRUE,
   wrapper_class       => [qw(input-integer break inline)];

has_field 'delete_after' =>
   type          => 'Boolean',
   wrapper_class => [qw(input-boolean inline shrink)];

has_field 'user_name' =>
   default       => 'mcp',
   required      => TRUE,
   size          => 10,
   wrapper_class => [qw(input-text break inline)];

has_field 'host' =>
   default       => 'localhost',
   required      => TRUE,
   size          => 18,
   wrapper_class => [qw(input-text inline shrink)];

has_field 'command' => type => 'TextArea', cols => 46, required => TRUE;

has_field 'directory', size => 46;

has_field 'condition', size => 46;

has_field 'crontab_min' =>
   label         => 'Minute',
   size          => 3,
   wrapper_class => [qw(input-text inline)];

has_field 'crontab_hour' =>
   label         => 'Hour',
   size          => 3,
   wrapper_class => [qw(input-text inline shrink)];

has_field 'crontab_mday' =>
   label         => 'Day of Month',
   size          => 3,
   wrapper_class => [qw(input-text break inline)];

has_field 'crontab_mon' =>
   label         => 'Month',
   size          => 3,
   wrapper_class => [qw(input-text inline shrink)];

has_field 'crontab_wday' =>
   label => 'Day of Week',
   size  => 3;

has_field 'submit' => type => 'Button';

# owner_id     => foreign_key_data_type( 1, 'owner' ),
# group_id     => foreign_key_data_type( 1, 'group' ),
# permissions  => { accessor      => '_permissions',
#                   data_type     => 'smallint',
#                   default_value => 488,
#                   is_nullable   => FALSE, },

use namespace::autoclean -except => META;

1;
