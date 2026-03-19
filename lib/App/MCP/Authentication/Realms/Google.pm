package App::MCP::Authentication::Realms::Google;

use App::MCP::Util qw( create_token );
use MIME::Base64   qw( decode_base64url );
use Moo;

extends 'App::MCP::Authentication::Realms::OAuth';

around 'redirect_params' => sub {
   my ($orig, $self, $state) = @_;

   my $params = $orig->($self, $state);

   $params->{nonce}         = substr create_token, 0, 12;
   $params->{response_type} = 'code';
   $params->{scope}         = 'openid email';

   return $params;
};

around 'token_params' => sub {
   my ($orig, $self, $code) = @_;

   my $params = $orig->($self, $code);

   $params->{grant_type} = 'authorization_code';

   return $params;
};

sub decode_tokens {
   my ($self, $content) = @_;

   return $self->json_parser->decode($content);
}

sub get_claim {
   my ($self, $tokens) = @_;

   return {} unless $tokens && $tokens->{id_token};

   my ($header, $claim, $crypt) = split m{ \. }mx, $tokens->{id_token};

   return $self->json_parser->decode(decode_base64url($claim));
}

use namespace::autoclean;

1;
