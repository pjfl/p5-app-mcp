package App::MCP::Role::JSONParser;

use App::MCP::Constants qw( FALSE TRUE );
use Type::Utils         qw( class_type );
use JSON::MaybeXS       qw( );
use Moo::Role;

has 'json_parser' =>
   is      => 'lazy',
   isa     => class_type(JSON::MaybeXS::JSON),
   default => sub { JSON::MaybeXS->new( convert_blessed => TRUE ) };

use namespace::autoclean;

1;
