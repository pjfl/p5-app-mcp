package App::MCP::Role::APIAuthentication;

use 5.010001;
use namespace::sweep;

use App::MCP::Worker::Crypt::SRP::Blowfish;
use App::MCP::Functions        qw( get_salt );
use Class::Usul::Constants;
use Class::Usul::Crypt         qw( decrypt );
use Class::Usul::Functions     qw( bson64id bson64id_time throw );
use HTTP::Status               qw( HTTP_BAD_REQUEST HTTP_EXPECTATION_FAILED
                                   HTTP_OK HTTP_UNAUTHORIZED );
use TryCatch;
use Unexpected::Functions      qw( Unspecified );
use Moo::Role;

requires qw( config log schema transcoder );

my $Sessions = {}; my $Users = [];

# Public methods
sub authenticate {
   my ($self, $req) = @_; $req->authenticate;

   my $user      = $self->_find_user_from( $req );
   my $sess      = $self->_find_or_create_session( $user );
   my $user_name = $user->username;
   my $token     = $req->body->param->{M1_token}
      or throw error => 'User [_1] no M1 token',
               args  => [ $user_name ], rv => HTTP_EXPECTATION_FAILED;
   my $srp       = App::MCP::Worker::Crypt::SRP::Blowfish->new;

   $srp->server_init( $user_name, $user->password, @{ $sess->{auth_keys} } );
   $srp->server_verify_M1( $token )
      or throw error => 'User [_1] M1 token verification failed',
               args  => [ $user_name ], rv => HTTP_UNAUTHORIZED;

   my $content   = { id => $sess->{id}, M2_token => $srp->server_compute_M2, };

   $sess->{shared_secret} = $srp->get_secret_K;

   return { code => HTTP_OK, content => $content, };
}

sub authenticate_params {
   my ($self, $id, $key, $params) = @_;

   $params or throw error => 'Request [_1] has no content',
                    args  => [ $id ], rv => HTTP_UNAUTHORIZED;

   try { $params = $self->transcoder->decode( decrypt $key, $params ) }
   catch ($e) {
      $self->log->error( $e );
      throw error => 'Request [_1] authentication failed with key [_2]',
            args  => [ $id, $key ], rv => HTTP_UNAUTHORIZED;
   }

   return $params;
}

sub exchange_pub_keys {
   my ($self, $req) = @_; $req->authenticate;

   my $client_pub_key = $req->params->{public_key};
   my $user           = $self->_find_user_from( $req );
   my $sess           = $self->_find_or_create_session( $user );
   my $srp            = App::MCP::Worker::Crypt::SRP::Blowfish->new;
   my $user_name      = $user->username;

   $srp->server_verify_A( $client_pub_key )
      or throw error => 'User [_1] client public key verification failed',
               args  => [ $user_name ], rv => HTTP_UNAUTHORIZED;
   $srp->server_init( $user_name, $user->password );

   my ($server_pub_key, $server_priv_key) = $srp->server_compute_B;

   $sess->{auth_keys} = [ $client_pub_key, $server_pub_key, $server_priv_key ];

   my $salt    = get_salt $user->password;
   my $content = { public_key => $server_pub_key, salt => $salt, };

   return { code => HTTP_OK, content => $content, };
}

sub get_session {
   my ($self, $id) = @_;

   $id or throw class => Unspecified, args => [ 'session id' ],
                rv    => HTTP_BAD_REQUEST;

   my $sess = $Sessions->{ $id }
      or throw error => 'Session [_1 ] not found',
               args  => [ $id ], rv => HTTP_UNAUTHORIZED;

   my $max_age = $sess->{max_age}; my $now = time;

   $max_age and $now - $sess->{last_used} > $max_age
      and delete $Sessions->{ $id }
      and throw error => 'Session [_1] expired',
                args  => [ $id ], rv => HTTP_UNAUTHORIZED;
   $sess->{last_used} = $now;
   return $sess;
}

# Private methods
sub _find_or_create_session {
   my ($self, $user) = @_; my $sess;

   try        { $sess = $self->get_session( $Users->[ $user->id ] ) }
   catch ($e) { # Create a new session
      $self->log->debug( $e );

      my $id = $Users->[ $user->id ] = bson64id;

      $sess = $Sessions->{ $id } = {
         id        => $id,
         key       => $user->username,
         last_used => bson64id_time( $id ),
         max_age   => $self->config->max_session_age,
         role_id   => $user->role_id,
         user_id   => $user->id, };
   }

   return $sess;
}

sub _find_user_from {
   my ($self, $req) = @_;

   my $user_name = $req->args->[ 0 ] // 'undef';
   my $user_rs   = $self->schema->resultset( 'User' );
   my $user      = $user_rs->find_by_name( $user_name );

   $user->active or throw error => 'User [_1] account inactive',
                          args  => [ $user_name ], rv => HTTP_UNAUTHORIZED;
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