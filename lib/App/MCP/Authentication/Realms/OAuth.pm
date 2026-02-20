package App::MCP::Authentication::Realms::OAuth;

use HTML::Forms::Constants qw( EXCEPTION_CLASS FALSE NUL TRUE );
use HTML::Forms::Types     qw( CodeRef HashRef Int );
use App::MCP::Util         qw( create_token new_uri );
use Type::Utils            qw( class_type );
use Unexpected::Functions  qw( throw RedirectToLocation UnauthorisedAccess
                               UnknownToken Unspecified );
use Acme::JWT;
use HTTP::Tiny;
use Moo;

extends 'App::MCP::Authentication::Realms::DBIC';
with    'App::MCP::Role::JSONParser';
with    'App::MCP::Role::Redis';

has 'config' =>
   is       => 'ro',
   isa      => class_type('App::MCP::Config'),
   required => TRUE;

has 'providers' => is => 'ro', isa => HashRef, default => sub { {} };

has 'ua_timeout' => is => 'ro', isa => Int, default => 30;

has 'uri_for_action' => is => 'ro', isa => CodeRef, required => TRUE;

has '_ua' =>
   is      => 'lazy',
   isa     => class_type('HTTP::Tiny'),
   default => sub { HTTP::Tiny->new(timeout => shift->ua_timeout) };

sub authenticate {
   my ($self, $args) = @_;

   my $user = $args->{user};

   throw Unspecified, ['user'] unless $user;

   my $method = $self->validate_ip_method;

   $user->$method($args->{address}) if $args->{address} && $user->can($method);

   my ($domain) = reverse split m{ @ }mx, $user->email;
   my $provider = $self->providers->{$domain};

   throw 'OAuth Provider [_1] unknown', [$domain] unless $provider;

   my $token   = $args->{params}->{$provider->{token_key}};
   my $request = $args->{params}->{$provider->{request_key}};

   $self->_redirect_oauth_provider($provider, $user) unless $token;

   throw UnauthorisedAccess unless $request;

   my $claim_method = '_get_claim_' . $provider->{name};
   my $claimed      = $self->$claim_method($provider, $request);

   throw 'Email address mismatch' unless $user->email eq $claimed->{email};

   return TRUE;
}

sub find_user {
   my ($self, $args) = @_;

   my $params = $args->{params};
   my $token  = $params->{state}; # Can add // other provider key...

   if ($token) {
      my $key     = "oauth-${token}";
      my $user_id = $self->redis_client->get($key);

      throw UnknownToken, [$token] unless $user_id;

      $self->redis_client->del($key);
      $args->{username} = $user_id;
   }

   return $self->next::method($args);
}

# Private methods
sub _get_claim_google {
   my ($self, $provider, $request) = @_;

   my $cb_url  = $self->uri_for_action->('misc/oauth');
   my $params  = {
      client_id     => $provider->{client_id},
      client_secret => $provider->{client_secret},
      code          => $request,
      grant_type    => 'authorization_code',
      redirect_uri  => $cb_url->as_string,
   };
   my $content = $self->_ua->www_form_urlencode($params);
   my $headers = { 'Content-Type' => 'application/x-www-form-urlencoded' };
   my $options = { content => $content, headers => $headers };
   my $res     = $self->_ua->post($provider->{access_url}, $options);

   $self->_throw_error($res) unless $res->{success};

   $content = $self->json_parser->decode($res->{content});

   # TODO: Consider what next?
   # So we have an access token.
   # But to what end. What protected resources might we want?
   # my $access_token  = $content->{access_token};
   # my $refresh_token = $content->{refresh_token};

   # TODO: Not happy with this shitfest
   return Acme::JWT->decode($content->{id_token}, 'Unused', FALSE);
}

sub _redirect_oauth_provider {
   my ($self, $provider, $user) = @_;

   my $token = create_token;

   $self->redis_client->set_with_ttl("oauth-${token}", $user->id, 180);

   my $method  = '_redirect_oauth_' . $provider->{name};
   my $uri     = $self->$method($provider, $token);
   my $message = ucfirst($provider->{name}) . ' authentication';

   throw RedirectToLocation, [$uri, $message];
}

sub _redirect_oauth_google {
   my ($self, $provider, $token) = @_;

   my $nonce  = substr create_token, 0, 12;
   my $cb_url = $self->uri_for_action->('misc/oauth');
   my $params = {
      client_id     => $provider->{client_id},
      nonce         => $nonce,
      redirect_uri  => $cb_url->as_string,
      response_type => 'code',
      scope         => 'openid email',
      state         => $token,
   };
   my $query  = $self->_ua->www_form_urlencode($params);

   return new_uri 'https', $provider->{request_url} . "?${query}";
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
