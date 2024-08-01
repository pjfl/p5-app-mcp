package App::MCP::Session;

use App::MCP::Constants     qw( FALSE TRUE );
use Class::Usul::Cmd::Types qw( ConfigProvider );
use Type::Utils             qw( class_type );
use App::MCP::Redis;
use Plack::Session::State::Cookie;
use Plack::Session::Store::Cache;
use Moo;

with 'App::MCP::Role::JSONParser';

has 'config' => is => 'ro', isa => ConfigProvider, required => TRUE;

has 'redis' =>
   is      => 'lazy',
   isa     => class_type('App::MCP::Redis'),
   default => sub {
      my $self = shift;

      return App::MCP::Redis->new(
         client_name => $self->config->prefix . '_session_store',
         config => $self->config->redis
      );
   };

sub middleware_config {
   my $self = shift;

   return (
      state => Plack::Session::State::Cookie->new(
         expires     => 7_776_000,
         httponly    => TRUE,
         path        => $self->config->mount_point,
         samesite    => 'None',
         secure      => TRUE,
         session_key => $self->config->prefix.'_session',
      ),
      store => Plack::Session::Store::Cache->new(cache => $self)
   );
}

sub get {
   my ($self, $key) = @_;

   return $self->json_parser->decode($self->redis->get($key));
}

sub remove {
   my ($self, $key) = @_;

   return $self->redis->del($key);
}

sub set {
   my ($self, $key, $value) = @_;

   return $self->redis->set($key, $self->json_parser->encode($value));
}

use namespace::autoclean;

1;
