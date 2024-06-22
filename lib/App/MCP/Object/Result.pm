package App::MCP::Object::Result;

use HTML::StateTable::Constants qw( FALSE NUL TRUE );
use HTML::StateTable::Types     qw( ArrayRef Object Str Undef );
use Moo;

with 'HTML::StateTable::Result::Role';

has 'cell_traits' => is => 'ro', isa => ArrayRef[Str], default => sub { [] };

has 'name' => is => 'ro', isa => Str, required => TRUE;

has 'value' => is => 'ro', isa => Object|Str|Undef, default => NUL;

use namespace::autoclean;

1;
