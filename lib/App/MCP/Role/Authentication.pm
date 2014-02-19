package App::MCP::Role::Authentication;

use 5.010001;
use namespace::sweep;

use Class::Usul::Constants;
use Class::Usul::Crypt         qw( encrypt decrypt );
use Class::Usul::Crypt::Util   qw( dh_base dh_mod );
use Class::Usul::Functions     qw( bson64id bson64id_time create_token throw );
use Crypt::DH;
use Crypt::Eksblowfish::Bcrypt qw( bcrypt );
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
   my $token     = $req->body->param->{authenticate}
      or throw error => 'User [_1] no password',
                args => [ $user_name ], rv => HTTP_EXPECTATION_FAILED;
   my $password  = decrypt $sess->{shared_secret}, $token;

   $user->password eq bcrypt( $password, $user->password )
      or throw error => 'User [_1] authentication failed',
                args => [ $user_name ], rv => HTTP_UNAUTHORIZED;

   $token = encrypt $sess->{shared_secret}, $self->transcoder->encode
      ( { id => $sess->{id}, token => $sess->{token}, } );

   return { code => HTTP_OK, content => { token => $token } };
}

sub authenticate_params {
   my ($self, $key, $token, $params) = @_;

   $params or throw error => 'Request [_1] has no content',
                     args => [ $key ], rv => HTTP_UNAUTHORIZED;

   try { $params = $self->transcoder->decode( decrypt $token, $params ) }
   catch ($e) {
      $self->log->error( $e );
      throw error => 'Request [_1] authentication failed with token [_2]',
             args => [ $key, $token ], rv => HTTP_UNAUTHORIZED;
   }

   return $params;
}

sub exchange_key {
   my ($self, $req) = @_; $req->authenticate;

   my $client_pub_key = $req->params->{public_key};
   my $user           = $self->_find_user_from( $req );
   my $sess           = $self->_find_or_create_session( $user );
   my $dh             = Crypt::DH->new( g => dh_base, p => dh_mod );

   $dh->generate_keys;

   my $salt           = __get_salt( $user->password );
   my $server_pub_key = encrypt $user->password, NUL.$dh->pub_key;
   my $content        = { public_key => $server_pub_key, salt => $salt, };

   $sess->{shared_secret} = $dh->compute_secret( $client_pub_key );

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
         token     => create_token,
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

# Private functions
sub __get_salt {
   my $password = shift; my @parts = split m{ [\$] }mx, $password;

   $parts[ -1 ] = substr $parts[ -1 ], 0, 22;

   return join '$', @parts;
}

1;

__END__

=pod

=encoding utf8

=head1 Name

App::MCP::Role::Authentication - One-line description of the modules purpose

=head1 Synopsis

   use App::MCP::Role::Authentication;
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
