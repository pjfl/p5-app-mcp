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

=pod

=encoding utf-8

=head1 Name

App::MCP::Authentication::Realms::OAuth - Base class for OAuth authentication

=head1 Synopsis

   package App::MCP::Authentication::Realms::MyProvider;

   use Moo;

   extends 'App::MCP::Authentication::Realms::OAuth';

=head1 Description

Base class for OAuth authentication. Extends the
L<DBIC authentication realm|App::MCP::Authentication::Realms::DBIC>

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=item C<config>

A required reference to L<App::MCP::Config>

=cut

has 'config' =>
   is       => 'ro',
   isa      => class_type('App::MCP::Config'),
   required => TRUE;

=item C<provider>

A hash reference of OAuth providers and their respective configuration
attributes

=cut

has 'provider' => is => 'ro', isa => HashRef, default => sub { {} };

=item C<ua_timeout>

How long in seconds should the UA wait for responses from the OAuth provider?
Defaults to thirty seconds

=cut

has 'ua_timeout' => is => 'ro', isa => Int, default => 30;

=item C<uri_for_action>

A required code reference. This is called with an action path and URI
positional arguments

=cut

has 'uri_for_action' => is => 'ro', isa => CodeRef, required => TRUE;

has '_ua' =>
   is      => 'lazy',
   isa     => class_type('HTTP::Tiny'),
   default => sub { HTTP::Tiny->new(timeout => shift->ua_timeout) };

with 'App::MCP::Role::Redis';

=back

=head1 Subroutines/Methods

Defines the following methods;

=over 3

=item C<find_user>

   $user_object = $self->find_user($args);

Finds a user object from the username/userid/email provided

The C<args> hash reference keys are;

=over 3

=item params.state

Used to fetch the username from the local object store. This was set by the
redirect call to the OAuth provider. Sets this username on the C<args> passed
to C<find_user> in the parent class

=back

Returns a L<user object|DBIx::Class::Core> iff it exists or undefined otherwise

=cut

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

=item C<authenticate>

   $bool = $self->authenticate($args);

Authenticates the supplied claim

The C<args> hash reference keys are;

=over 3

=item address

This IP address of the originating request. Optional

=item params.code

The OAuth providers request token. This is exchanged for an C<access_token>.
The C<access_token> is used to obtain the OAuth provider's user claim

=item params.state

This random token was created when the user was redirected to the OAuth
provider. Used as a key to store the username in the local object store

=item user

An instance of the L<user object|DBIx::Class::Core>. Returned by calling
C<find_user>

=back

Calls C<user>.C<$validate_ip_method> to validate the user's IP address

Returns C<TRUE> if successful, raises an exception otherwise

=cut

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

=item C<decode_tokens>

   $tokens = $self->decode_tokens($provider_response);

Decodes the response obtained by exchanging the request token (C<code>) for
the C<access_token>

The provider response is a string of URL encoded key/value pairs

Returns a hash reference

=cut

sub decode_tokens {
   my ($self, $content) = @_;

   my $tokens = {};

   for my $pair (split m{ \& }mx, $content) {
      my ($key, $value) = split m{ \= }mx, $pair;

      $tokens->{$key} = $value;
   }

   return $tokens;
}

=item C<get_claim>

   $claim = $self->get_claim($tokens);

Use C<tokens>.C<access_token> to fetch the user claim from the OAuth
provider

Returns a hash reference which must contain an C<email> key

=cut

sub get_claim {
   my ($self, $tokens) = @_;

   my $access_token = $tokens->{access_token} or return {};
   my $headers      = { 'Authorization' => "Bearer ${access_token}" };
   my $url          = $self->provider->{userinfo_url};
   my $res          = $self->_ua->get($url, { headers => $headers });

   $self->_throw_error($res) unless $res->{success};

   return $self->json_parser->decode($res->{content});
}

=item C<redirect_params>

   $params = $self->redirect_params($state);

Keys/values used in the query string of the redirect to the OAuth provider

Returns a hash reference

=cut

sub redirect_params {
   my ($self, $state) = @_;

   my $cb_url = $self->uri_for_action->('misc/oauth', [lc $self->realm]);

   return {
      client_id    => $self->provider->{client_id},
      redirect_uri => $cb_url->as_string,
      state        => $state,
   };
}

=item C<token_params>

   $params = $self->token_params($code);

Keys/values used in the query string of the request for the C<access_token>
from the OAuth provider

Returns a hash reference

=cut

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
   my $key   = "oauth-${state}";

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

__END__

=back

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<App::MCP::Authentication::Realms::DBIC>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module. Please report problems to
http://rt.cpan.org/NoAuth/Bugs.html?Dist=App::MCP.
Patches are welcome

=head1 Acknowledgements

Larry Wall - For the Perl programming language

=head1 Author

Peter Flanigan, C<< <pjfl@cpan.org> >>

=head1 License and Copyright

Copyright (c) 2025 Peter Flanigan. All rights reserved

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See L<perlartistic>

This program is distributed in the hope that it will be useful,
but WITHOUT WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE

=cut

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
