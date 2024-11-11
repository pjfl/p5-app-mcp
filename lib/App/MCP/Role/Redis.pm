package App::MCP::Role::Redis;

use App::MCP::Constants qw( FALSE TRUE );
use Unexpected::Types   qw( Str );
use Type::Utils         qw( class_type );
use App::MCP::Redis;
use Moo::Role;

has 'redis_client' =>
   is      => 'lazy',
   isa     => class_type('App::MCP::Redis'),
   default => sub {
      my $self   = shift;
      my $config = $self->config;
      my $name   = $config->prefix . '_' . $self->redis_client_name;

      return App::MCP::Redis->new(
         client_name => $name, config => $config->redis
      );
   };

has 'redis_client_name' => is => 'ro', isa => Str, default => 'unknown';

use namespace::autoclean;

1;
