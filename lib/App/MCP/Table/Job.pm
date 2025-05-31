package App::MCP::Table::Job;

use HTML::StateTable::Constants qw( FALSE NUL SPC TABLE_META TRUE );
use Moo;
use HTML::StateTable::Moo;

extends 'HTML::StateTable';
with    'HTML::StateTable::Role::Form';
with    'HTML::StateTable::Role::Configurable';

has '+caption' => default => 'Jobs List';

has '+configurable_action' => default => 'api/table_preference';

has '+configurable_control_location' => default => 'TopRight';

has '+form_buttons' => default => sub {
   return [{
      action    => 'job/remove',
      class     => 'remove-item',
      selection => 'select_one',
      value     => 'Remove Job',
   }];
};

has '+form_control_location' => default => 'BottomRight';

has '+icons' => default => sub { shift->context->uri_for_icons->as_string };

has '+page_control_location' => default => 'TopLeft';

has '+page_size_control_location' => default => 'BottomLeft';

set_table_name 'job';

setup_resultset sub {
   return shift->context->model('Job');
};

has_column 'id' =>
   cell_traits => ['Numeric'],
   label       => 'ID',
   width       => '3rem';

has_column 'job_name' =>
   label    => 'Job Name',
   sortable => TRUE,
   title    => 'Sort by job',
   link     => sub {
      my $self    = shift;
      my $context = $self->table->context;

      return $context->uri_for_action('job/view', [$self->result->id]);
   };

has_column 'type';

has_column 'created' => cell_traits => ['DateTime'];

has_column 'host';

has_column 'user_name' => label => 'User Name';

has_column 'command';

has_column 'check' =>
   cell_traits => ['Checkbox'],
   label       => SPC,
   value       => 'id';

use namespace::autoclean -except => TABLE_META;

1;
