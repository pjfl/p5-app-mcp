package App::MCP::Model::API;

use 5.010001;
use namespace::sweep;

use Moo;
use App::MCP::Constants;
use App::MCP::Functions    qw( trigger_input_handler );
use Class::Usul::Crypt     qw( encrypt decrypt );
use Class::Usul::Functions qw( bson64id bson64id_time create_token throw );
use Class::Usul::Time      qw( time2str );
use Class::Usul::Types     qw( Object );
use HTTP::Status           qw( HTTP_BAD_REQUEST HTTP_CREATED HTTP_NOT_FOUND
                               HTTP_OK HTTP_UNAUTHORIZED );
use JSON                   qw( );
use TryCatch;
use Unexpected::Functions  qw( Unspecified );

extends q(App::MCP::Model);

my $Sessions = {}; my $Users = [];

# Private attributes
has '_transcoder' => is => 'lazy', isa => Object,
   builder        => sub { JSON->new }, reader => 'transcoder';

# Public methods
sub create_event {
   my ($self, $req) = @_; $req->authenticate;

   my $schema = $self->schema;
   my $run_id = $req->args->[ 0 ] // 'undef';
   my $pe_rs  = $schema->resultset( 'ProcessedEvent' )
                        ->search( { runid   => $run_id },
                                  { columns => [ 'token' ] } );
   my $pevent = $pe_rs->first
      or throw error => 'Runid [_1] not found',
               args  => [ $run_id ], rv => HTTP_NOT_FOUND;
   my $event  = $self->_authenticate_params
      ( $run_id, $pevent->token, $req->body->param->{event} );

   try        { $event = $schema->resultset( 'Event' )->create( $event ) }
   catch ($e) { throw error => $e, rv => HTTP_BAD_REQUEST }

   trigger_input_handler $ENV{MCP_DAEMON_PID};
   return { code    => HTTP_CREATED,
            content => { message => 'Event '.$event->id.' created' } };
}

sub create_job {
   my ($self, $req) = @_; $req->authenticate;

   my $sess = $self->_get_session( $req->args->[ 0 ] // 'undef' );
   my $job  = $self->_authenticate_params
      ( $sess->{key}, $sess->{token}, $req->body->param->{job} );

   $job->{owner} = $sess->{user_id}; $job->{group} = $sess->{role_id};

   try        { $job = $self->schema->resultset( 'Job' )->create( $job ) }
   catch ($e) { throw error => $e, rv => HTTP_BAD_REQUEST }

   return { code    => HTTP_CREATED,
            content => { message => 'Job '.$job->id.' created' } };
}

sub exception_handler {
   my ($self, $req, $e) = @_;

   return { code => $e->rv, content => { message => "${e}" } };
}

sub find_or_create_session {
   my ($self, $req) = @_; $req->authenticate;

   my $user_name = $req->args->[ 0 ] // 'undef';
   my $user_rs   = $self->schema->resultset( 'User' ); my $user;

   try        { $user = $user_rs->find_by_name( $user_name ) }
   catch ($e) { throw error => $e, rv => HTTP_NOT_FOUND }

   $user->active or throw error => 'User [_1] account inactive',
                          args  => [ $user_name ], rv => HTTP_UNAUTHORIZED;

   my ($code, $sess) = $self->_find_or_create_session( $user );

   my $salt  = __get_salt( $user->password );
   my $hash  = { id => $sess->{id}, token => $sess->{token}, };
   my $token = encrypt $user->password, $self->transcoder->encode( $hash );

   return { code => $code, content => { salt => $salt, token => $token } };
}

sub snapshot_state {
   my ($self, $req) = @_;

   my $frames = [];
   my $id     = bson64id;
   my $schema = $self->schema;
   my $level  = $req->args->[ 0 ] // 1;
   my $job_rs = $schema->resultset( 'Job' );
   my $jobs   = $job_rs->search( { id => { '>' => 1 } }, {
         'columns'  => [ qw( fqjn id parent_id state.name type ) ],
         'join'     => 'state',
         'order_by' => [ 'parent_id', 'id' ], } );

   try {
      for my $job ($jobs->all) {
         push @{ $frames }, { fqjn      => $job->fqjn,
                              id        => $job->id,
                              parent_id => $job->parent_id,
                              state     => NUL.$job->state->name,
                              type      => NUL.$job->type, };
      }
   }
   catch ($e) { throw error => $e, rv => HTTP_BAD_REQUEST }

   my $minted  = time2str undef, bson64id_time( $id );
   my $content = { id => $id, jobs => $frames, minted => $minted };

   return { code => HTTP_OK, content => $content };
}

# Private methods
sub _authenticate_params {
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

sub _find_or_create_session {
   my ($self, $user) = @_; my $code = HTTP_OK; my $sess;

   try        { $sess = $self->_get_session( $Users->[ $user->id ] ) }
   catch ($e) { # Create a new session
      $self->log->debug( $e );

      my $id = $Users->[ $user->id ] = bson64id; $code = HTTP_CREATED;

      $sess = $Sessions->{ $id } = {
         id        => $id,
         key       => $user->username,
         last_used => bson64id_time( $id ),
         max_age   => $self->config->max_session_age,
         role_id   => $user->role_id,
         token     => create_token,
         user_id   => $user->id, };
   }

   return ( $code, $sess );
}

sub _get_session {
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

App::MCP::Model::API - One-line description of the modules purpose

=head1 Synopsis

   use App::MCP::Model::API;
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
