package App::MCP::Role::APIAuthentication;

use namespace::autoclean;

use App::MCP::Constants    qw( EXCEPTION_CLASS TRUE );
use App::MCP::Functions    qw( get_hashed_pw get_salt );
use Class::Usul::Crypt     qw( decrypt );
use Class::Usul::Functions qw( base64_decode_ns base64_encode_ns
                               bson64id bson64id_time throw );
use Crypt::SRP;
use Digest::MD5 qw( md5_hex );
use HTTP::Status           qw( HTTP_BAD_REQUEST HTTP_EXPECTATION_FAILED
                               HTTP_OK HTTP_UNAUTHORIZED );
use Try::Tiny;
use Unexpected::Functions  qw( Unspecified );
use Moo::Role;

requires qw( config log schema transcoder );

my $Sessions = {}; my $Users = [];

# Public methods
sub authenticate {
   my ($self, $req) = @_; $req->authenticate;

   my $user     = $self->_find_user_from( $req );
   my $sess     = $self->_find_or_create_session( $user );
   my $username = $user->username;
   my $token    = $req->body_params->( 'M1_token' )
      or throw 'User [_1] no M1 token', [ $username ],
            rv => HTTP_EXPECTATION_FAILED;
   my $srp      = Crypt::SRP->new( 'RFC5054-2048bit', 'SHA512' );
   my $verifier = base64_decode_ns get_hashed_pw $user->password;
   my $salt     = get_salt $user->password;

   $token       = base64_decode_ns $token;
   $self->log->debug( 'Auth M1 token '.(md5_hex $token) );
   $self->log->debug( 'Auth verifier '
                      .(md5_hex "${username}${salt}${verifier}") );
   $srp->server_init( $username, $verifier, $salt, @{ $sess->{auth_keys} } );
   $srp->server_verify_M1( $token )
      or throw 'User [_1] M1 token verification failed', [ $username ],
            rv => HTTP_UNAUTHORIZED;
   $token       = base64_encode_ns $srp->server_compute_M2;

   my $content  = { id => $sess->{id}, M2_token => $token, };

   $sess->{shared_secret} = base64_encode_ns $srp->get_secret_K;

   return { code => HTTP_OK, content => $content, view => 'json', };
}

sub authenticate_params {
   my ($self, $id, $key, $encrypted) = @_; my $params;

   try   { $params = $self->transcoder->decode( decrypt $key, $encrypted ) }
   catch {
      $self->log->error( $_ );
      throw 'Request [_1] authentication failed with key [_2]', [ $id, $key ],
         rv => HTTP_UNAUTHORIZED;
   };

   return $params;
}

sub exchange_pub_keys {
   my ($self, $req) = @_; $req->authenticate;

   my $user           = $self->_find_user_from( $req );
   my $sess           = $self->_find_or_create_session( $user );
   my $srp            = Crypt::SRP->new( 'RFC5054-2048bit', 'SHA512' );
   my $client_pub_key = base64_decode_ns $req->query_params->( 'public_key' );
   my $username       = $user->username;

   $self->log->debug( 'Auth client pub key '.(md5_hex $client_pub_key ) );
   $srp->server_verify_A( $client_pub_key )
      or throw 'User [_1] client public key verification failed', [ $username ],
            rv => HTTP_UNAUTHORIZED;

   my $verifier = base64_decode_ns get_hashed_pw $user->password;
   my $salt     = get_salt $user->password;

   $srp->server_init( $username, $verifier, $salt );

   my ($server_pub_key, $server_priv_key) = $srp->server_compute_B;

   $sess->{auth_keys} = [ $client_pub_key, $server_pub_key, $server_priv_key ];
   $self->log->debug( 'Auth server pub key '.(md5_hex $server_pub_key ) );

   my $pub_key = base64_encode_ns $server_pub_key;
   my $content = { public_key => $pub_key, salt => $salt, };

   return { code => HTTP_OK, content => $content, view => 'json', };
}

sub get_session {
   my ($self, $id) = @_;

   $id or throw Unspecified, [ 'session id' ], rv => HTTP_BAD_REQUEST;

   my $sess = $Sessions->{ $id }
      or throw 'Session [_1 ] not found', [ $id ], rv => HTTP_UNAUTHORIZED;

   my $max_age = $sess->{max_age}; my $now = time;

   $max_age and $now - $sess->{last_used} > $max_age
      and delete $Sessions->{ $id }
      and throw 'Session [_1] expired', [ $id ], rv => HTTP_UNAUTHORIZED;
   $sess->{last_used} = $now;
   return $sess;
}

# Private methods
sub _find_or_create_session {
   my ($self, $user) = @_; my $sess;

   try   { $sess = $self->get_session( $Users->[ $user->id ] ) }
   catch { # Create a new session
      $self->log->debug( $_ );

      my $id = $Users->[ $user->id ] = bson64id;

      $sess = $Sessions->{ $id } = {
         id        => $id,
         key       => $user->username,
         last_used => bson64id_time( $id ),
         max_age   => $self->config->max_api_session_time,
         role_id   => $user->role_id,
         user_id   => $user->id, };
   };

   return $sess;
}

sub _find_user_from {
   my ($self, $req) = @_;

   my $username = $req->args->[ 0 ] // 'undef';
   my $user_rs  = $self->schema->resultset( 'User' );
   my $user     = $user_rs->find_by_name( $username );

   $user->active or throw 'User [_1] account inactive', [ $username ],
                       rv => HTTP_UNAUTHORIZED;
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

=head1 Dependencies

=over 3

=item L<Class::Usul>

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

Copyright (c) 2014 Peter Flanigan. All rights reserved

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
