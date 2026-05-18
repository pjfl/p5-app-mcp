package App::MCP::Role::APIAuthentication;

use App::MCP::Constants          qw( EXCEPTION_CLASS FALSE TRUE );
use HTTP::Status                 qw( HTTP_BAD_REQUEST HTTP_EXPECTATION_FAILED
                                     HTTP_NOT_FOUND HTTP_OK HTTP_UNAUTHORIZED );
use App::MCP::Util               qw( get_hashed_pw get_salt );
use Digest::MD5                  qw( md5_hex );
use MIME::Base64                 qw( decode_base64 encode_base64 );
use Unexpected::Functions        qw( throw AccountInactive Unspecified );
use Web::ComposableRequest::Util qw( bson64id bson64id_time );
use Crypt::SRP;
use Try::Tiny;
use Moo::Role;
use App::MCP::Attributes; # Will do namespace cleaning

requires qw( config log );

with 'App::MCP::Role::Redis';

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

   try   { $user = $self->_find_user_from($context) }
   catch { $result = [HTTP_NOT_FOUND, { message => "${_}" }] };

   return $self->_stash_response($context, $result) if $result;

   my $session        = $self->_find_or_create_session($user);
   my $srp            = Crypt::SRP->new('RFC5054-2048bit', 'SHA512');
   my $client_pub_key = decode_base64 $request->query_params->('public_key');
   my $username       = $user->user_name;
   my $message;

   $self->log->debug('Auth client pub key ' . (md5_hex $client_pub_key));
   $message = "User ${username} client public key verification failed";
   $result = [HTTP_UNAUTHORIZED, { message => $message }];

   return $self->_stash_response($context, $result)
      unless $srp->server_verify_A($client_pub_key);

   my $verifier = decode_base64 get_hashed_pw $user->password;
   my $salt     = get_salt $user->password;

   $self->log->debug("Server init - exchange pubkeys ${username} ${salt}");
   $srp->server_init($username, $verifier, $salt);

   my ($server_pub_key, $server_priv_key) = $srp->server_compute_B;

   $session->{auth_keys} = [$client_pub_key, $server_pub_key, $server_priv_key];

   $self->_set_session($session->{id}, $session);

   my $pub_key = encode_base64 $server_pub_key;

   $result = [HTTP_OK, { public_key => $pub_key, salt => $salt }];
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

   try   { $user = $self->_find_user_from($context) }
   catch { $result = [HTTP_NOT_FOUND, { message => "${_}" }] };

   return $self->_stash_response($context, $result) if $result;

   my $session  = $self->_find_or_create_session($user);
   my $username = $user->user_name;
   my $m1_token = $context->body_parameters->{'M1_token'};
   my $message  = "User ${username} M1 token not found";

   $result = [HTTP_NOT_FOUND, { message => $message }];

   return $self->_stash_response($context, $result) unless $m1_token;

   my $srp      = Crypt::SRP->new('RFC5054-2048bit', 'SHA512');
   my $verifier = decode_base64 get_hashed_pw $user->password;
   my $salt     = get_salt $user->password;
   my $token    = decode_base64 $m1_token;

   $self->log->debug("Server init - authenticate ${username} ${salt}");
   $self->log->debug('Auth M1 token ' . (md5_hex $token));
   $srp->server_init($username, $verifier, $salt, @{$session->{auth_keys}});
   $message = "User ${username} M1 token verification failed";
   $result = [HTTP_UNAUTHORIZED, { message => $message }];

   return $self->_stash_response($context, $result)
      unless $srp->server_verify_M1($token);

   $token = encode_base64 $srp->server_compute_M2;
   $session->{shared_secret} = encode_base64 $srp->get_secret_K;
   $self->_set_session($session->{id}, $session);
   $result = [HTTP_OK, { id => $session->{id}, M2_token => $token }];
   $self->_stash_response($context, $result);
   return;
}

sub get_session {
   my ($self, $session_id) = @_;

   throw Unspecified, ['session id'] unless $session_id;

   my $key     = $self->_session_key($session_id);
   my $session = $self->redis_client->get($key)
      or throw 'Session [_1] not found', [$session_id], rv => HTTP_UNAUTHORIZED;
   my $max_age = $session->{max_age};
   my $now     = time;

   if ($max_age and $now - $session->{last_used} > $max_age) {
      $self->redis_client->del($key);
      throw 'Session [_1] expired', [$session_id], rv => HTTP_UNAUTHORIZED;
   }

   $session->{last_used} = $now;
   $self->_set_session($session_id, $session);
   return $session;
}

# Private methods
sub _find_or_create_session {
   my ($self, $user) = @_;

   my $session_id = $self->_session_id($user);
   my $session;

   try   { $session = $self->get_session($session_id) }
   catch { # Create a new session
      $self->log->debug($_);
      $session_id = bson64id;
      $session    = {
         id        => $session_id,
         key       => $user->user_name,
         last_used => bson64id_time($session_id),
         max_age   => $self->session_ttl,
         role_id   => $user->role_id,
         user_id   => $user->id,
      };

      $self->_set_session($session_id, $session);
      $self->_session_id($user, $session_id);
   };

   return $session;
}

sub _find_user_from {
   my ($self, $context) = @_;

   my $name = $context->stash('username');
   my $user = $context->find_user({ username => $name });

   throw AccountInactive, [$self->name] unless $user->active;

   return $user;
}

sub _session_id {
   my ($self, $user, $session_id) = @_;

   my $key = 'worker_session_userid-' . $user->id;

   return $self->redis_client->get($key) unless $session_id;

   $self->redis_client->set_with_ttl($key, $session_id, $self->session_ttl);

   return $session_id;
}

sub _session_key {
   my ($self, $session_id) = @_; return "worker_session-${session_id}";
}

sub _set_session {
   my ($self, $session_id, $session) = @_;

   my $key = $self->_session_key($session_id);

   $self->redis_client->set_with_ttl($key, $session, $self->session_ttl);

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
