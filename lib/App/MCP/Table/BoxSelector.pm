package App::MCP::Table::BoxSelector;

use HTML::StateTable::Constants qw( FALSE NUL TABLE_META TRUE );
use Moo;
use HTML::StateTable::Moo;

extends 'HTML::StateTable';
with    'HTML::StateTable::Role::Form';
with    'HTML::StateTable::Role::Searchable';

has '+icons' => default => sub { shift->context->icons_uri->as_string };

has '+page_control_location' => default => 'TopLeft';

has '+page_size' => default => 20;

has '+page_size_control_location' => default => 'BottomLeft';

has '+searchable_control_location' => default => 'TopRight';

setup_resultset sub {
   my $self = shift;
   my $rs   = $self->context->model('Job');

   return $rs->search({ type => 'box' }, { prefetch => 'owner_rel' });
};

set_table_name 'boxselector';

has_column 'job_name' =>
   label      => 'Box Name',
   min_width  => '30ch',
   searchable => TRUE,
   sortable   => TRUE,
   title      => 'Sort by box name';

has_column 'owner_rel' => label => 'Owner';

has_column 'group_rel' => label => 'Group';

has_column 'check' =>
   cell_traits => ['Checkbox'],
   label       => 'Select',
   options     => { select_one => TRUE },
   value       => sub {
      my $cell = shift;

      return $cell->result->job_name;
   };

use namespace::autoclean -except => TABLE_META;

1;
