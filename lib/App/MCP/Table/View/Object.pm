package App::MCP::Table::View::Object;

use HTML::StateTable::Constants qw( FALSE SPC TABLE_META TRUE );
use HTML::StateTable::Types     qw( ArrayRef DBIxClass Str );
use App::MCP::Object::View;
use Moo;
use MooX::HandlesVia;
use HTML::StateTable::Moo;

extends 'HTML::StateTable';
with    'HTML::StateTable::Role::Form';

has '+form_classes' => default => sub { ['classic', 'fieldset'] };
has '+max_width'    => default => '50rem';
has '+no_count'     => default => TRUE;
has '+paging'       => default => FALSE;

has 'add_columns' =>
   is          => 'ro',
   isa         => ArrayRef,
   default     => sub { [] },
   handles_via => 'Array',
   handles     => { has_add_columns => 'count' };

has 'result' => is => 'ro', isa => DBIxClass, required => TRUE;

has 'table_class' => is => 'ro', isa => Str, default => 'object-view';

setup_resultset sub {
   my $self = shift;

   return App::MCP::Object::View->new(table => $self);
};

set_table_name 'object-view';

has_column 'name' =>
   label   => SPC,
   options => { notraits => TRUE },
   width   => '8rem';

has_column 'value' => label => SPC, min_width => '20rem';

use namespace::autoclean -except => TABLE_META;

1;
