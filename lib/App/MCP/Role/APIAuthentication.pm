package App::MCP::Role::APIAuthentication;

use App::MCP::Constants          qw( EXCEPTION_CLASS FALSE TRUE );
use HTTP::Status                 qw( HTTP_BAD_REQUEST HTTP_EXPECTATION_FAILED
                                     HTTP_OK HTTP_UNAUTHORIZED );
use App::MCP::Util               qw( get_hashed_pw get_salt );
use Class::Usul::Cmd::Util       qw( decrypt );
use Digest::MD5                  qw( md5_hex );
use MIME::Base64                 qw( decode_base64 encode_base64 );
use Unexpected::Functions        qw( throw AccountInactive Unspecified );
use Web::ComposableRequest::Util qw( bson64id bson64id_time );
use Crypt::SRP;
use Try::Tiny;
use Moo::Role;
use App::MCP::Attributes; # Will do namespace cleaning

requires qw( config log );

with 'App::MCP::Role::JSONParser';

my $Sessions = {};
my $Users = [];

# Public methods
sub authenticate : Auth('none') {
   my ($self, $context) = @_;

   my $request = $context->request;

   $request->authenticate_headers;

   my $user     = $self->_find_user_from($context);
   my $session  = $self->_find_or_create_session($user);
   my $username = $user->user_name;
   my $token    = $request->body_params->('M1_token')
      or throw 'User [_1] no M1 token', [$username],
            rv => HTTP_EXPECTATION_FAILED;
   my $srp      = Crypt::SRP->new('RFC5054-2048bit', 'SHA512');
   my $verifier = decode_base64 get_hashed_pw $user->password;
   my $salt     = get_salt $user->password;

   $token = decode_base64 $token;
   $self->log->debug('Auth M1 token ' . (md5_hex $token));
   $self->log->debug(
      'Server init - authenticate ' . (md5_hex "${username}${salt}")
   );
   $srp->server_init($username, $verifier, $salt, @{$session->{auth_keys}});

   throw 'User [_1] M1 token verification failed', [$username],
      rv => HTTP_UNAUTHORIZED unless $srp->server_verify_M1($token);

   $token = encode_base64 $srp->server_compute_M2;

   $session->{shared_secret} = encode_base64 $srp->get_secret_K;

   my $content = { id => $session->{id}, M2_token => $token };

   $context->stash(code => HTTP_OK, json => $content);
   return;
}

sub authenticate_params {
   my ($self, $id, $key, $encrypted) = @_;

   my $params;

   try   { $params = $self->json_parser->decode(decrypt $key, $encrypted) }
   catch {
      $self->log->error($_);
      throw 'Request [_1] authentication failed with key [_2]', [$id, $key],
         rv => HTTP_UNAUTHORIZED;
   };

   return $params;
}

sub exchange_keys : Auth('none') {
   my ($self, $context) = @_;

   my $request = $context->request;

   $request->authenticate_headers;

   my $user           = $self->_find_user_from($context);
   my $session        = $self->_find_or_create_session($user);
   my $srp            = Crypt::SRP->new('RFC5054-2048bit', 'SHA512');
   my $client_pub_key = decode_base64 $request->query_params->('public_key');
   my $username       = $user->user_name;

   $self->log->debug('Auth client pub key ' . (md5_hex $client_pub_key));

   throw 'User [_1] client public key verification failed', [$username],
      rv => HTTP_UNAUTHORIZED if $srp->server_verify_A($client_pub_key);

   my $verifier = decode_base64 get_hashed_pw $user->password;
   my $salt     = get_salt $user->password;

   $self->log->debug(
      'Server init - exchange pubkeys ' . (md5_hex "${username}${salt}")
   );
   $srp->server_init($username, $verifier, $salt);

   my ($server_pub_key, $server_priv_key) = $srp->server_compute_B;

   $session->{auth_keys} = [$client_pub_key, $server_pub_key, $server_priv_key];

   my $pub_key = encode_base64 $server_pub_key;
   my $content = { public_key => $pub_key, salt => $salt };

   $context->stash(code => HTTP_OK, json => $content);
   return;
}

sub get_session {
   my ($self, $id) = @_;

   throw Unspecified, ['session id'] unless $id;

   my $session = $Sessions->{$id}
      or throw 'Session [_1 ] not found', [$id], rv => HTTP_UNAUTHORIZED;
   my $max_age = $session->{max_age};
   my $now     = time;

   if ($max_age and $now - $session->{last_used} > $max_age) {
      delete $Sessions->{$id};
      throw 'Session [_1] expired', [$id], rv => HTTP_UNAUTHORIZED;
   }

   $session->{last_used} = $now;
   return $session;
}

# Private methods
sub _find_or_create_session {
   my ($self, $user) = @_;

   my $session;

   try   { $session = $self->_get_session($Users->[$user->id]) }
   catch { # Create a new session
      $self->log->debug($_);

      my $id = $Users->[$user->id] = bson64id;

      $session = $Sessions->{$id} = {
         id        => $id,
         key       => $user->user_name,
         last_used => bson64id_time($id),
         max_age   => $self->config->max_api_session_time,
         role_id   => $user->role_id,
         user_id   => $user->id,
      };
   };

   return $session;
}

sub _find_user_from {
   my ($self, $context) = @_;

   my $user = $context->find_user({ username => $self->name });

   throw AccountInactive, [$self->name] unless $user->active;

   return $user;
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
