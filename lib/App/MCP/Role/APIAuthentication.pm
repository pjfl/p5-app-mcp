package App::MCP::Role::APIAuthentication;

use App::MCP::Constants          qw( EXCEPTION_CLASS FALSE TRUE );
use HTTP::Status                 qw( HTTP_BAD_REQUEST HTTP_EXPECTATION_FAILED
                                     HTTP_NOT_FOUND HTTP_OK HTTP_UNAUTHORIZED );
use App::MCP::Util               qw( fp get_hashed_pw get_salt );
use MIME::Base64                 qw( decode_base64url encode_base64url );
use Unexpected::Functions        qw( throw AccountInactive Unspecified );
use Web::ComposableRequest::Util qw( bson64id bson64id_time );
use Crypt::SRP;
use Try::Tiny;
use Moo::Role;
use App::MCP::Attributes; # Will do namespace cleaning

requires qw( config json_parser log redis_client );

has 'session_ttl' =>
   is      => 'lazy',
   default => sub { shift->config->max_api_session_time };

# Public methods
sub exchange_keys : Auth('none') {
   my ($self, $context) = @_;

   my $request = $context->request;
   my $result;

   try   { $request->authenticate_headers }
   catch { $result = [HTTP_BAD_REQUEST, { message => "${_}" }] };

   return $self->_stash_response($context, $result) if $result;

   my $user;

   try   { $user = $self->_find_active_user($context) }
   catch { $result = [HTTP_NOT_FOUND, { message => "${_}" }] };

   return $self->_stash_response($context, $result) if $result;

   my $session       = $self->_find_or_create_session($user);
   my $srp           = Crypt::SRP->new('RFC5054-2048bit', 'SHA512');
   my $public_key    = $request->query_parameters->{public_key};
   my $client_pubkey = decode_base64url $public_key;
   my $username      = $user->user_name;
   my $message;

   $self->log->debug('Exchange_keys: Client pubkey ' . fp $client_pubkey);

   $message = "User ${username} client public key verification failed";
   $result  = [HTTP_UNAUTHORIZED, { message => $message }];

   return $self->_stash_response($context, $result)
      unless $srp->server_verify_A($client_pubkey);

   my $verifier = decode_base64url get_hashed_pw $user->password;
   my $salt     = get_salt $user->password;

   $srp->server_init($username, $verifier, $salt);

   my ($server_pubkey, $server_privkey) = $srp->server_compute_B;

   $session->{auth_keys} = [
      encode_base64url($client_pubkey),
      encode_base64url($server_pubkey),
      encode_base64url($server_privkey)
   ];

   $self->log->debug('Exchange_keys: Server pubkey ' . fp $server_pubkey);
   $self->log->debug("Exchange_keys: ${username} ${salt}");
   $self->log->debug('Exchange_keys: Session id ' . $session->{id});

   $self->_set_session($session->{id}, $session);

   my $pubkey = encode_base64url $server_pubkey;

   $result = [HTTP_OK, { public_key => $pubkey, salt => $salt }];
   $self->_stash_response($context, $result);
   return;
}

sub authenticate : Auth('none') {
   my ($self, $context) = @_;

   my $request = $context->request;
   my $result;

   try   { $request->authenticate_headers }
   catch { $result = [HTTP_BAD_REQUEST, { message => "${_}" }] };

   return $self->_stash_response($context, $result) if $result;

   my $user;

   try   { $user = $self->_find_active_user($context) }
   catch { $result = [HTTP_NOT_FOUND, { message => "${_}" }] };

   return $self->_stash_response($context, $result) if $result;

   my $session  = $self->_find_or_create_session($user);
   my $username = $user->user_name;
   my $m1_token = $context->body_parameters->{'M1_token'};
   my $message  = "User ${username} M1 token not found";

   $result = [HTTP_NOT_FOUND, { message => $message }];

   return $self->_stash_response($context, $result) unless $m1_token;

   my $srp      = Crypt::SRP->new('RFC5054-2048bit', 'SHA512');
   my $verifier = decode_base64url get_hashed_pw $user->password;
   my $salt     = get_salt $user->password;
   my $token    = decode_base64url $m1_token;
   my $keys     = [ map { decode_base64url($_) } @{$session->{auth_keys}}];

   $self->log->debug('Authenticate: Session id ' . $session->{id});
   $self->log->debug('Authenticate: Server pubkey ' . fp $keys->[1]);
   $self->log->debug("Authenticate: ${username} ${salt}");
   $self->log->debug('Authenticate: M1 token ' . fp $token);

   $srp->server_init($username, $verifier, $salt, @{$keys});

   $message = "User ${username} M1 token verification failed";
   $result  = [HTTP_UNAUTHORIZED, { message => $message }];

   return $self->_stash_response($context, $result)
      unless $srp->server_verify_M1($token);

   $token = encode_base64url $srp->server_compute_M2;
   $session->{shared_secret} = encode_base64url $srp->get_secret_K;
   $self->_set_session($session->{id}, $session);
   $result = [HTTP_OK, { id => $session->{id}, M2_token => $token }];
   $self->_stash_response($context, $result);
   return;
}

sub get_session {
   my ($self, $session_id) = @_;

   my $session = $self->_get_session($session_id);
   my $max_age = $session->{max_age};
   my $now     = time;

   if ($max_age and $now - $session->{last_used} > $max_age) {
      $self->redis_client->del($self->_session_key($session_id));
      throw 'Session [_1] expired', [$session_id], rv => HTTP_UNAUTHORIZED;
   }

   $session->{last_used} = $now;
   $self->_set_session($session_id, $session);
   return $session;
}

# Private methods
sub _create_session {
   my ($self, $user) = @_;

   my $session_id = $self->_set_session_id($user, bson64id);
   my $session    = {
      id        => $session_id,
      key       => $user->user_name,
      last_used => time,
      max_age   => $self->session_ttl,
      role_id   => $user->role_id,
      user_id   => $user->id,
   };

   return $self->_set_session($session_id, $session);
}

sub _find_or_create_session {
   my ($self, $user) = @_;

   throw Unspecified, ['user'] unless $user;

   my $session;

   try   { $session = $self->get_session($self->_get_session_id($user)) }
   catch {
      $self->log->debug($_);
      $session = $self->_create_session($user);
   };

   return $session;
}

sub _find_active_user {
   my ($self, $context) = @_;

   my $user = $context->stash('user');

   throw AccountInactive, [$user->user_name] unless $user->active;

   return $user;
}

sub _get_session {
   my ($self, $session_id) = @_;

   throw Unspecified, ['session id'] unless $session_id;

   my $key     = $self->_session_key($session_id);
   my $encoded = $self->redis_client->get($key)
      or throw 'Session [_1] not found', [$session_id], rv => HTTP_UNAUTHORIZED;

   return $self->json_parser->decode($encoded);
}

sub _get_session_id {
   my ($self, $user) = @_;

   my $key = 'worker_session_userid-' . $user->id;

   return $self->redis_client->get($key);
}

sub _set_session_id {
   my ($self, $user, $session_id) = @_;

   throw Unspecified, ['session id'] unless $session_id;

   my $key = 'worker_session_userid-' . $user->id;

   $self->redis_client->set_with_ttl($key, $session_id, $self->session_ttl);

   return $session_id;
}

sub _session_key {
   my ($self, $session_id) = @_; return "worker_session-${session_id}";
}

sub _set_session {
   my ($self, $session_id, $session) = @_;

   my $key     = $self->_session_key($session_id);
   my $encoded = $self->json_parser->encode($session);

   $self->redis_client->set_with_ttl($key, $encoded, $self->session_ttl);

   return $session;
}

1;

__END__

=pod

=encoding utf8

=head1 Name

App::MCP::Role::APIAuthentication - One-line description of the modules purpose

=head1 Synopsis

   with App::MCP::Role::APIAuthentication;
   # Brief but working code examples

=head1 Description

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=back

=head1 Subroutines/Methods

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Crypt::SRP>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module. Please report problems to
http://rt.cpan.org/NoAuth/Bugs.html?Dist=App-MCP.
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
