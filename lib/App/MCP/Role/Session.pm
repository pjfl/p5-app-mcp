package App::MCP::Role::Session;

use Type::Utils qw( class_type );
use App::MCP::Session;
use Moo::Role;

requires qw( config );

has 'session' =>
   is      => 'lazy',
   isa     => class_type('App::MCP::Session'),
   default => sub { App::MCP::Session->new(config => shift->config) };

use namespace::autoclean;

1;
