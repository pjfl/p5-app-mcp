package App::MCP::Table::Bugs;

use HTML::StateTable::Constants qw( FALSE NUL SPC TABLE_META TRUE );
use Moo;
use HTML::StateTable::Moo;

extends 'HTML::StateTable';
with    'HTML::StateTable::Role::Form';
with    'HTML::StateTable::Role::Configurable';

has '+caption' => default => 'Bugs List';

has '+configurable_action' => default => 'api/table_preference';

has '+configurable_control_location' => default => 'TopRight';

has '+form_control_location' => default => 'BottomRight';

has '+icons' => default => sub { shift->context->uri_for_icons->as_string };

has '+page_control_location' => default => 'TopLeft';

has '+page_size_control_location' => default => 'BottomLeft';

set_table_name 'bugs';

setup_resultset sub {
   my $self = shift;
   my $rs   = $self->context->model('Bug');

   return $rs->search({}, { order_by => 'id' });
};

has_column 'id' =>
   cell_traits => ['Numeric'],
   label       => 'Bug ID',
   link        => sub {
      my $self    = shift;
      my $context = $self->table->context;

      return $context->uri_for_action('bug/view', [$self->result->id]);
   },
   sortable    => TRUE,
   title       => 'Sort by bug id',
   width       => '3rem';

has_column 'title' =>
   label    => 'Title',
   sortable => TRUE,
   title    => 'Sort by title';

has_column 'user_id' => label => 'Owner', value => 'owner.user_name';

has_column 'created' => cell_traits => ['DateTime'];

has_column 'state' => sortable => TRUE, title => 'Sort by state';

has_column 'check' =>
   cell_traits => ['Checkbox'],
   label       => SPC,
   value       => 'id';

use namespace::autoclean -except => TABLE_META;

1;
