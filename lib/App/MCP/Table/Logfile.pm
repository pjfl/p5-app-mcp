package App::MCP::Table::Logfile;

use HTML::StateTable::Constants qw( FALSE NUL SPC TABLE_META TRUE );
use File::DataClass::Types      qw( Directory );
use Format::Human::Bytes;
use HTML::StateTable::ResultSet::File::List;
use Moo;
use HTML::StateTable::Moo;

extends 'HTML::StateTable';
with    'HTML::StateTable::Role::Form';

has '+caption' => default => 'Logfile List';

has '+icons' => default => sub { shift->context->uri_for_icons->as_string };

has '+paging' => default => FALSE;

has 'format_number' => is => 'ro', default => sub { Format::Human::Bytes->new };

setup_resultset sub {
   my $self = shift;

   return HTML::StateTable::ResultSet::File::List->new(
      directory    => $self->context->config->logsdir,
      result_class => 'App::MCP::Log::Result::List',
      table        => $self
   );
};

set_table_name 'logfile_list';

has_column 'name' =>
   label => 'Name',
   link  => sub {
      my $cell    = shift;
      my $context = $cell->table->context;
      my $name    = $cell->result->uri_arg;

      return $context->uri_for_action('logfile/view', [$name]);
   },
   sortable => TRUE;

has_column 'modified' =>
   cell_traits => ['DateTime'],
   label       => 'Modified',
   sortable    => TRUE;

has_column 'size' =>
   cell_traits => ['Numeric'],
   value       => sub {
      my $cell = shift;

      return $cell->table->format_number->base2($cell->result->size);
   };

use namespace::autoclean -except => TABLE_META;

1;
