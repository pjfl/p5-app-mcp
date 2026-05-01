package App::MCP::Table::Docs;

use HTML::StateTable::Constants qw( FALSE NUL SPC TABLE_META TRUE );
use File::DataClass::Types      qw( Bool Directory Str );
use Format::Human::Bytes;
use HTML::StateTable::ResultSet::File::List;
use Moo;
use HTML::StateTable::Moo;

extends 'HTML::StateTable';
with    'HTML::StateTable::Role::Form';
with    'HTML::StateTable::Role::HighlightRow';
with    'HTML::StateTable::Role::Tag';
with    'App::MCP::Role::FileMeta';

has 'action' =>
   is      => 'lazy',
   isa     => Str,
   default => sub { my $moniker = shift->moniker; "${moniker}/application" };

has 'action_view' =>
   is      => 'lazy',
   isa     => Str,
   default => sub { my $moniker = shift->moniker; "${moniker}/application" };

has 'directory' =>
   is       => 'lazy',
   isa      => Directory,
   init_arg => undef,
   default  => sub {
      my $self = shift;

      return $self->file->directory($self->_directory);
   };

has 'extensions' => is => 'ro', isa => Str, default => 'pm';

has 'moniker' => is => 'ro', isa => Str, default => 'doc';

has 'selected' => is => 'ro', isa => Str, predicate => 'has_selected';

has 'selectonly' => is => 'ro', isa => Bool, default => FALSE;

has '+caption' => default => 'Documentation';

has '+form_buttons' => default => sub { shift->_build_form_buttons };

has '+form_control_location' =>
   default => sub { [qw(TopLeft BottomLeft BottomRight)] };

has '+icons' => default => sub { shift->context->icons_uri->as_string };

has '+paging' => default => FALSE;

has '+tag_breadcrumbs' => default => TRUE;

has '+tag_control_location' => default => 'Title';

has '+tag_direction' => default => 'right';

has '+tag_names' => default => sub { shift->_build_tag_names };

has '+title_location' => default => 'outer';

has '_directory' => is => 'ro', isa => Str, init_arg => 'directory';

has '_format_number' => is => 'ro', default => sub {
   return Format::Human::Bytes->new;
};

set_table_name 'documentation';

setup_resultset sub {
   my $self = shift;

   return HTML::StateTable::ResultSet::File::List->new(
      allow_directories => TRUE,
      directory         => $self->directory,
      extension         => $self->extensions,
      recurse           => FALSE,
      result_class      => 'App::MCP::File::Result::List',
      table             => $self,
   );
};

has_column 'icon' => cell_traits => ['Icon'], label => 'Type';

has_column 'name' =>
   sortable => TRUE,
   link     => sub {
      my $cell = shift; return $cell->table->_build_name_link($cell);
   };

# has_column 'size' =>
#    cell_traits => ['Numeric'],
#    value       => sub {
#       my $cell = shift;

#       return $cell->table->_format_number->base2($cell->result->size);
#    };

# has_column 'modified' => cell_traits => ['DateTime'], sortable => TRUE;

sub highlight_row {
   my ($self, $row) = @_;

   return FALSE unless $self->selected;

   return $self->selected eq $row->result->name ? TRUE : FALSE;
}

# Private methods
sub _build_form_buttons {
   my $self  = shift;
   my $empty = { 'TopLeft' => [], 'BottomLeft' => [], 'BottomRight' => [] };

   return $empty if $self->selectonly;

   my $params  = {};

   $params->{directory} = $self->_directory if $self->_directory;
   $params->{selected}  = $self->selected   if $self->has_selected;

   my $context = $self->context;

   return {
      'TopLeft' => [],
      'BottomLeft' => [],
      'BottomRight' => []
   };
}

sub _build_name_link {
   my ($self, $cell) = @_;

   my $result = $cell->result;
   my $params = {};

   if ($result->type eq 'directory') {
      $params->{directory}  = $self->_qualified_directory($result);
      $params->{extensions} = $self->extensions if $self->extensions;

      return $self->context->uri_for_action($self->action, [], $params);
   }
   elsif ($result->type eq 'file') {
      my $dir  = $self->_qualified_directory;
      my $file = $result->uri_arg;

      $params->{directory} = $dir  if $dir;
      $params->{selected}  = $file if $file;

      return $self->context->uri_for_action($self->action_view, [], $params);
   }

   return;
}

sub _build_tag_names {
   my $self  = shift;
   my $names = ['Home'];

   push @{$names}, split m{ / }mx, $self->file->to_path($self->_directory)
      if $self->_directory;

   my $tuples = [];
   my $directory = NUL;

   for my $name (@{$names}) {
      my $params = {};

      unless ($name eq 'Home') {
         $directory = $self->file->to_uri($directory, $name);
         $params = { directory => $directory };
      }

      $params->{extensions} = $self->extensions if $self->extensions;
      $params->{selected} = $self->selected if $self->has_selected;

      my $uri = $self->context->uri_for_action($self->action, [], $params);

      push @{$tuples}, [$name, $uri];
   }

   return $tuples;
}

sub _qualified_directory {
   my ($self, $result) = @_;

   return $self->file->to_uri($self->_directory) unless $result;

   return $self->file->to_uri($self->_directory, $result->uri_arg);
}

use namespace::autoclean -except => TABLE_META;

1;
