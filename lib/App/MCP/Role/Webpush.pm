package App::MCP::Role::Webpush;

use App::MCP::Constants    qw( FALSE NUL TRUE );
use File::DataClass::Types qw( Int Str );
use App::MCP::Util         qw( create_token encode_token );
use Crypt::JWT             qw( encode_jwt );
use MIME::Base64           qw( decode_base64url encode_base64url );
use Type::Utils            qw( class_type );
use Crypt::PK::ECC;
use HTTP::Request::Webpush;
use HTTP::Tiny;
use URI;
use Moo::Role;

requires qw( config json_parser redis_client );

=pod

=encoding utf-8

=head1 Name

App::MCP::Role::Webpush - A client role for the browser Web Push API

=head1 Synopsis

   use Moo;

   with 'App::MCP::Role::Webpush';

=head1 Description

A client role for the browser Web Push API

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=item C<jwt_secret>

Used to create and verify JWT access tokens

=cut

has 'jwt_secret' =>
   is      => 'lazy',
   isa     => Str,
   default => sub { shift->config->db_password };

=item C<ua_timeout>

Defaults to thirty seconds. How long should the HTTP user agent wait for
responses

=cut

has 'ua_timeout' => is => 'ro', isa => Int, default => 30;

=item C<vapid_lifetime>

Defaults to five minutes. The life time in seconds for the VAPID token

=cut

has 'vapid_lifetime' => is => 'ro', isa => Int, default => 300;

=item C<webpush_request_ttl>

Defaults to ninety seconds. How long should the C<TTL> in the webpush request
header be?

=cut

has 'webpush_request_ttl' => is => 'ro', isa => Int, default => 90;

# Private attributes
has '_pusher' =>
   is      => 'lazy',
   isa     => class_type('HTTP::Request::Webpush'),
   default => sub {
      my $self   = shift;
      my $pusher = HTTP::Request::Webpush->new;

      if (my $encoded = $self->redis_client->get('service-worker-keys')) {
         my $keys = $self->json_parser->decode($encoded);

         $pusher->authbase64($keys->{public}, $keys->{private});
      }

      return $pusher;
   };

has '_pusher_priv_key' =>
   is      => 'lazy',
   isa     => class_type('Crypt::PK::ECC'),
   default => sub {
      my $self   = shift;
      my $pk_ecc = Crypt::PK::ECC->new;

      $pk_ecc->import_key_raw($self->_pusher->{'app-key'}, 'secp256r1');

      return $pk_ecc;
   };

has '_ua' =>
   is      => 'lazy',
   isa     => class_type('HTTP::Tiny'),
   default => sub { HTTP::Tiny->new(timeout => shift->ua_timeout) };

=back

=head1 Subroutines/Methods

Defineds the following methods;

=over 3

=item C<decode_access_token>

   $claim = $self->decode_access_token($token);

=cut

sub decode_access_token {
   my ($self, $token) = @_;

   return unless $token;

   my ($salt, $payload, $verify) = split m{ \. }mx, $token;

   return unless $salt && $payload && $verify;

   my $calculated = encode_token $self->jwt_secret, "${salt}${payload}";

   return unless $verify eq $calculated;

   return $self->json_parser->decode(decode_base64url($payload));
}

=item C<encode_access_token>

   $token = $self->encode_access_token(\%claim?);

=cut

sub encode_access_token {
   my ($self, $claim) = @_;

   $claim //= {};
   $claim->{_refreshed} = time;
   $claim->{_created} //= $claim->{_refreshed};

   my $salt    = encode_base64url(pack('H*', create_token));
   my $payload = encode_base64url($self->json_parser->encode($claim));
   my $verify  = encode_token $self->jwt_secret, "${salt}${payload}";

   return "${salt}.${payload}.${verify}";
}

=item C<http_get>

   $hash_ref = $self->http_get($uri, \%query_params?, \%options?);

=cut

sub http_get {
   my ($self, $uri, $params, $options) = @_;

   $params //= {};
   $options //= {};

   my $query;

   $query = $self->_ua->www_form_urlencode($params) if scalar keys %{$params};

   $uri = "${uri}?${query}" if $query;

   my $res = $self->_ua->get($uri, $options);

   return $self->decode_response($res);
}

=item C<http_post>

   $hash_ref = $self->http_post($uri, \%content);

Returns a hash reference with the C<success> attribute set to true if
successful. Returns a hash reference containing an C<error> attribute
otherwise

=cut

sub http_post {
   my ($self, $uri, $content) = @_;

   return { error => "Parameter 'uri' not specified" } unless $uri;

   $content //= { message => 'Something happened' };

   my $encoded = $self->json_parser->encode($content);
   my $headers = { 'Content-Type' => 'application/json' };
   my $params  = { content => $encoded, headers => $headers };
   my $res     =  $self->_ua->post($uri, $params);

   return $self->decode_response($res);
}

=item C<service_worker_push>

   $hash_ref = $self->service_worker_push($user_id, \%content);

If a user with the given C<user_id> has registered a Web Push subscription push
the supplied C<content>

Returns a hash reference with the C<success> attribute set to true if
successful. Returns a hash reference containing an C<error> attribute
otherwise

=cut

sub service_worker_push {
   my ($self, $user_id, $content) = @_;

   return { error => "Parameter 'user_id' not specified" } unless $user_id;

   $content //= { message => 'Something happened' };

   my $worker_key   = "service-worker-${user_id}";
   my $subscription = $self->redis_client->get($worker_key);
   my $message      = "User '${user_id}' no service worker subscription";

   return { error => $message } unless $subscription;

   my $req = $self->_pusher;

   $req->subscription($self->json_parser->decode($subscription));
   $req->subject('mailto:mcp@example.com');
   $req->content($self->json_parser->encode($content));
   $req->header('TTL' => $self->webpush_request_ttl);
   $req->encode();
   $req->remove_header('::std_case'); # Strange artifact
   $self->_set_authorisation($self->vapid_lifetime);

   my $params = { content => $req->content, headers => $req->headers };
   my $res    = $self->_ua->post($req->uri, $params);

   return $self->decode_response($res);
}

# Private methods
# Was getting error: VAPID token expiration is too long
# Because time has different zones on client and server
sub _set_authorisation {
   my ($self, $vapid_exp) = @_;

   my $req    = $self->_pusher;
   my $origin = URI->new($req->{subscription}->{endpoint});

   $origin->path_query(NUL);
   $vapid_exp ||= 86400;

   my $payload = { aud => "${origin}", exp => time + $vapid_exp };

   $payload->{'sub'} = $req->{subject} if $req->{subject};

   my $key   = $self->_pusher_priv_key;
   my $token = encode_jwt(alg => 'ES256', key => $key, payload => $payload);

   $req->remove_header('Authorization');
   $req->header('Authorization' => "WebPush ${token}");
   return;
}

use namespace::autoclean;

1;

__END__

=back

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<HTTP::Request::Webpush>

=item L<HTTP::Tiny>

=item L<Moo::Role>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module. Please report problems to
http://rt.cpan.org/NoAuth/Bugs.html?Dist=App-MCP.  Patches are welcome

=head1 Acknowledgements

Larry Wall - For the Perl programming language

=head1 Author

Peter Flanigan, C<< <pjfl@cpan.org> >>

=head1 License and Copyright

Copyright (c) 2026 Peter Flanigan. All rights reserved

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
