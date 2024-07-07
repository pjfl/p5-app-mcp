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

has '+icons' => default => sub {
   return shift->context->request->uri_for('img/icons.svg')->as_string;
};

has '+page_control_location' => default => 'TopLeft';

has '+page_size_control_location' => default => 'BottomLeft';

set_table_name 'bugs';

setup_resultset sub {
   return shift->context->model('Bug');
};

has_column 'id' =>
   cell_traits => ['Numeric'],
   label       => 'ID',
   width       => '3rem';

has_column 'state';

has_column 'user_id' => label => 'Owner', value => 'owner.user_name';

# has_column 'title' =>
#    label    => 'Title',
#    sortable => TRUE,
#    title    => 'Sort by title',
#    link     => sub {
#       my $self    = shift;
#       my $context = $self->table->context;

#       return $context->uri_for_action('bug/view', [$self->result->id]);
#    };

#has_column 'created' => cell_traits => ['DateTime'];

has_column 'check' =>
   cell_traits => ['Checkbox'],
   label       => SPC,
   value       => 'id';

use namespace::autoclean -except => TABLE_META;

1;
