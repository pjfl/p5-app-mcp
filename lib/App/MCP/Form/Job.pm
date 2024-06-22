package App::MCP::Form::Job;

use HTML::Forms::Constants qw( FALSE META NUL TRUE );
use Moo;
use HTML::Forms::Moo;

extends 'HTML::Forms::Model::DBIC';
with    'HTML::Forms::Role::Defaults';

has '+name'         => default => 'Job';
has '+title'        => default => 'Job';
has '+info_message' => default => 'Create or edit jobs';
has '+item_class'   => default => 'Job';

has_field 'job_name' => required => TRUE;

has_field 'type' =>
   type    => 'Select',
   options => [
      { label => 'Box', value => 'box' }, { label => 'Job', value => 'job' }
   ];

has_field 'expected_rv' =>
   type    => 'PosInteger',
   default => 0,
   label   => 'Expected RV';

has_field 'delete_after' => type => 'Boolean';

has_field 'host' => default => 'localhost', required => TRUE;

has_field 'user_name' => default => 'mcp', required => TRUE;

has_field 'command' => required => TRUE;

has_field 'crontab';

has_field 'condition';

has_field 'directory';

has_field 'submit' => type => 'Button';

# owner_id     => foreign_key_data_type( 1, 'owner' ),
# group_id     => foreign_key_data_type( 1, 'group' ),
# permissions  => { accessor      => '_permissions',
#                   data_type     => 'smallint',
#                   default_value => 488,
#                   is_nullable   => FALSE, },

# parent_id    => nullable_foreign_key_data_type,


use namespace::autoclean -except => META;

1;
