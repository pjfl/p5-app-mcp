package App::MCP::Table::Logfile::ViewApache;

use HTML::StateTable::Constants qw( FALSE NUL SPC TABLE_META TRUE );
use HTML::StateTable::Types     qw( Str );
use Type::Utils                 qw( class_type );
use HTML::StateTable::ResultSet::File::View;
use Moo;
use HTML::StateTable::Moo;

extends 'HTML::StateTable';
with    'HTML::StateTable::Role::Filterable';
with    'HTML::StateTable::Role::Searchable';
with    'HTML::StateTable::Role::Form';

has 'logfile' => is => 'ro', isa => Str, required => TRUE;

has 'redis' =>
   is       => 'ro',
   isa      => class_type('App::MCP::Redis'),
   required => TRUE;

has '+form_buttons' => default => sub {
   return [{
      action    => 'logfile/clear_cache',
      selection => 'disable_on_select',
      value     => 'Clear Cache',
   }];
};

has '+form_control_location' => default => 'BottomLeft';

has '+icons' => default => sub { shift->context->uri_for_icons->as_string };

has '+name' => default => sub {
   my $file = shift->logfile;

   $file =~ s{ \. log \z }{}mx;

   return $file
};

has '+page_control_location' => default => 'TopRight';

has '+title_location' => default => 'inner';

setup_resultset sub {
   my $self   = shift;
   my $config = $self->context->config;

   return HTML::StateTable::ResultSet::File::View->new(
      directory    => $config->logfile->parent,
      file         => $self->logfile,
      redis        => $self->redis,
      result_class => 'App::MCP::Log::Result::ViewApache',
      table        => $self,
   );
};

has_column 'timestamp' =>
   cell_traits => ['DateTime'],
   label       => 'Timestamp',
   searchable  => TRUE,
   sortable    => TRUE,
   title       => 'Sort by date and time',
   width       => '16ch';

has_column 'ip_address' => label => 'IP Address';

has_column 'method';

has_column 'path';

has_column 'status' => cell_traits => ['Numeric'];

has_column 'size' => cell_traits => ['Numeric'];

has_column 'referer';

use namespace::autoclean -except => TABLE_META;

1;
