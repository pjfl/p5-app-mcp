package App::MCP::Authentication::Realms::OAuth;

use HTML::Forms::Constants qw( EXCEPTION_CLASS FALSE NUL TRUE );
use HTML::Forms::Types     qw( CodeRef HashRef Int );
use App::MCP::Util         qw( create_token new_uri );
use Type::Utils            qw( class_type );
use Unexpected::Functions  qw( throw RedirectToLocation UnauthorisedAccess
                               UnknownToken Unspecified );
use HTTP::Tiny;
use Moo;

extends 'App::MCP::Authentication::Realms::DBIC';
with    'App::MCP::Role::JSONParser';
with    'App::MCP::Role::Redis';

has 'config' =>
   is       => 'ro',
   isa      => class_type('App::MCP::Config'),
   required => TRUE;

has 'provider' => is => 'ro', isa => HashRef, default => sub { {} };

has 'ua_timeout' => is => 'ro', isa => Int, default => 30;

has 'uri_for_action' => is => 'ro', isa => CodeRef, required => TRUE;

has '_ua' =>
   is      => 'lazy',
   isa     => class_type('HTTP::Tiny'),
   default => sub { HTTP::Tiny->new(timeout => shift->ua_timeout) };

around 'find_user' => sub {
   my ($orig, $self, $args) = @_;

   if (my $state = $args->{params}->{state}) {
      my $key      = "oauth-${state}";
      my $username = $self->redis_client->get($key);

      throw UnknownToken, [$key] unless $username;

      $self->redis_client->del($key);
      $args->{username} = $username;
   }

   return $orig->($self, $args);
};

sub authenticate {
   my ($self, $args) = @_;

   my $user = $args->{user};

   throw Unspecified, ['user'] unless $user;

   my $method = $self->validate_ip_method;

   $user->$method($args->{address}) if $args->{address} && $user->can($method);

   my $state = $args->{params}->{state};

   $self->_redirect_oauth_provider($user) unless $state;

   my $code = $args->{params}->{code};

   throw UnauthorisedAccess unless $code;

   my $tokens = $self->_get_tokens($code);
   my $claim  = $self->get_claim($tokens);
   my $email  = $claim->{email};

   throw UnauthorisedAccess unless $email && $email eq $user->email;

   return TRUE;
}

sub decode_tokens {
   my ($self, $content) = @_;

   my $tokens = {};

   for my $pair (split m{ \& }mx, $content) {
      my ($key, $value) = split m{ \= }mx, $pair;

      $tokens->{$key} = $value;
   }

   return $tokens;
}

sub get_claim {
   my ($self, $tokens) = @_;

   my $access_token = $tokens->{access_token} or return {};
   my $headers      = { 'Authorization' => "Bearer ${access_token}" };
   my $url          = $self->provider->{userinfo_url};
   my $res          = $self->_ua->get($url, { headers => $headers });

   $self->_throw_error($res) unless $res->{success};

   return $self->json_parser->decode($res->{content});
}

sub redirect_params {
   my ($self, $state) = @_;

   my $cb_url = $self->uri_for_action->('misc/oauth', [lc $self->realm]);

   return {
      client_id    => $self->provider->{client_id},
      redirect_uri => $cb_url->as_string,
      state        => $state,
   };
}

sub token_params {
   my ($self, $code) = @_;

   my $cb_url = $self->uri_for_action->('misc/oauth', [lc $self->realm]);

   return {
      client_id     => $self->provider->{client_id},
      client_secret => $self->provider->{client_secret},
      code          => $code,
      redirect_uri  => $cb_url->as_string,
   };
}

# Private methods
sub _get_tokens {
   my ($self, $code) = @_;

   my $params  = $self->token_params($code);
   my $content = $self->_ua->www_form_urlencode($params);
   my $headers = { 'Content-Type' => 'application/x-www-form-urlencoded' };
   my $options = { content => $content, headers => $headers };
   my $res     = $self->_ua->post($self->provider->{access_url}, $options);

   $self->_throw_error($res) unless $res->{success};

   return $self->decode_tokens($res->{content});
}

sub _redirect_oauth_provider {
   my ($self, $user) = @_;

   my $state = create_token;
   my $key   = "oauth-${token}";

   $self->redis_client->set_with_ttl($key, $user->id, 180);

   my $params  = $self->redirect_params($state);
   my $query   = $self->_ua->www_form_urlencode($params);
   my $uri     = new_uri 'https', $self->provider->{request_url} . "?${query}";
   my $message = ucfirst($self->provider->{name}) . ' authentication';

   throw RedirectToLocation, [$uri, $message];
}

sub _throw_error {
   my ($self, $res) = @_;

   my $message = $res->{content} // 'No response content';

   if ('{' eq substr $message, 0, 1) {
      my $decoded = $self->json_parser->decode($message);

      $message = $decoded->{message} // 'No content message';
   }

   my $error = ($res->{reason} ? $res->{reason} . ': ' : NUL) . $message;

   throw $error;
}

use namespace::autoclean;

1;
