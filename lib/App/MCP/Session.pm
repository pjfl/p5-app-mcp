package App::MCP::Session;

use App::MCP::Constants     qw( FALSE TRUE );
use Class::Usul::Cmd::Types qw( ConfigProvider );
use Plack::Session::State::Cookie;
use Plack::Session::Store::Cache;
use Moo;

with 'App::MCP::Role::JSONParser';

has 'config' => is => 'ro', isa => ConfigProvider, required => TRUE;

with 'App::MCP::Role::Redis';

has '+redis_client_name' => default => 'session_store';

sub middleware_config {
   my $self   = shift;
   my $config = $self->_hash2list($self->config->state_cookie);

   return (
      state => Plack::Session::State::Cookie->new(@{$config}),
      store => Plack::Session::Store::Cache->new(cache => $self)
   );
}

sub get {
   my ($self, $key) = @_;

   return $self->json_parser->decode($self->redis_client->get($key));
}

sub remove {
   my ($self, $key) = @_;

   return $self->redis_client->del($key);
}

sub set {
   my ($self, $key, $value) = @_;

   return $self->redis_client->set($key, $self->json_parser->encode($value));
}

# Private methods
sub _hash2list {
   my ($self, $hash) = @_;

   my $list = [];

   for my $key (keys %{$hash}) {
      push @{$list}, $key, $hash->{$key};
   }

   return $list;
}

use namespace::autoclean;

1;
