package App::MCP::Table::View::CSV;

use HTML::StateTable::Constants qw( FALSE NUL SPC TABLE_META TRUE );
use HTML::StateTable::Types     qw( Str );
use Type::Utils                 qw( class_type );
use HTML::StateTable::ResultSet::File::View;
use Moo;
use HTML::StateTable::Moo;

extends 'HTML::StateTable';
with    'HTML::StateTable::Role::Configurable';
with    'HTML::StateTable::Role::Filterable';
with    'HTML::StateTable::Role::Searchable';
with    'HTML::StateTable::Role::Form';

has '+configurable_action' => default => 'api/table_preference';

has '+configurable_control_location' => default => 'TopRight';

has '+form_buttons' => default => sub {
   return [{
      action    => 'logfile/clear_cache',
      selection => 'disable_on_select',
      value     => 'Clear Cache',
   }];
};

has '+form_control_location' => default => 'BottomRight';

has '+icons' => default => sub { shift->context->icons_uri->as_string };

has '+name' => default => sub { shift->logfile };

has '+page_control_location' => default => 'TopLeft';

has '+page_size_control_location' => default => 'BottomLeft';

has '+searchable_control_location' => default => 'TopRight';

has '+title_location' => default => 'inner';

has 'logfile' => is => 'ro', isa => Str, required => TRUE;

has 'redis' =>
   is       => 'ro',
   isa      => class_type('App::MCP::Redis'),
   required => TRUE;

setup_resultset sub {
   my $self   = shift;
   my $config = $self->context->config;

   return HTML::StateTable::ResultSet::File::View->new(
      directory    => $config->logfile->parent,
      file         => $self->logfile,
      redis        => $self->redis,
      result_class => 'App::MCP::File::Result::CSV',
      table        => $self,
   );
};

has_column 'timestamp' =>
   cell_traits => ['DateTime'],
   label       => 'Timestamp',
   searchable  => TRUE,
   sortable    => TRUE,
   title       => 'Sort by date and time';

has_column 'status' =>
   filterable => TRUE,
   sortable   => TRUE,
   title      => 'Sort by status';

has_column 'username' =>
   filterable => TRUE,
   searchable => TRUE,
   sortable   => TRUE,
   title      => 'Sort by user name';

has_column 'source' =>
   filterable => TRUE,
   searchable => TRUE,
   sortable   => TRUE,
   title      => 'Sort by source identifier';

has_column 'runid' =>
   filterable => TRUE,
   searchable => TRUE;

has_column 'pid' =>
   cell_traits => ['Numeric'],
   filterable  => TRUE,
   searchable  => TRUE;

has_column 'remainder' =>
   cell_traits => ['Remainder'],
   label       => 'Line',
   searchable  => TRUE;

use namespace::autoclean -except => TABLE_META;

1;
