package App::MCP::Model::API;

use namespace::autoclean;

use App::MCP::Constants    qw( NUL TRUE );
use App::MCP::Util         qw( trigger_input_handler );
use Class::Usul::Functions qw( throw );
use Class::Usul::Types     qw( Object );
use HTTP::Status           qw( HTTP_BAD_REQUEST HTTP_CREATED
                               HTTP_NOT_FOUND HTTP_OK );
use JSON::MaybeXS          qw( );
use Try::Tiny;
use Moo;

extends 'App::MCP::Model';

has '+moniker' => default => 'api';

# Private attributes
has '_transcoder' => is => 'lazy', isa => Object,
   builder        => sub { JSON::MaybeXS->new }, reader => 'transcoder';

with 'App::MCP::Role::APIAuthentication';

# Public methods
sub create_event {
   my ($self, $req) = @_; my $event; $req->authenticate_headers;

   my $schema = $self->schema;
   my $run_id = $req->query_params->( 'runid' );
   my $pe_rs  = $schema->resultset( 'ProcessedEvent' )
                       ->search( { runid   => $run_id },
                                 { columns => [ 'token' ] } );
   my $pevent = $pe_rs->first
     or throw 'Runid [_1] not found', [ $run_id ], rv => HTTP_NOT_FOUND;
   my $params = $self->authenticate_params
      ( $run_id, $pevent->token, $req->body_params->( 'event' ) );

   try    { $event = $schema->resultset( 'Event' )->create( $params ) }
   catch  { throw $_, rv => HTTP_BAD_REQUEST };

   trigger_input_handler $self->config->appclass->env_var( 'DAEMON_PID' );

   return { code    => HTTP_CREATED,
            content => { message => 'Event '.$event->id.' created' },
            view    => 'json', };
}

sub create_job {
   my ($self, $req) = @_; my $job; $req->authenticate_headers;

   my $sess_id = $req->query_params->( 'sessionid' );
   my $sess    = $self->get_session( $sess_id );
   my $params  = $self->authenticate_params
      ( $sess->{key}, $sess->{shared_secret}, $req->body_params->( 'job' ) );

   $params->{owner_id} = $sess->{user_id};
   $params->{group_id} = $sess->{role_id};

   try    { $job = $self->schema->resultset( 'Job' )->create( $params ) }
   catch  { throw $_, rv => HTTP_BAD_REQUEST };

   return { code    => HTTP_CREATED,
            content => { message => 'Job '.$job->id.' created' },
            view    => 'json', };
}

sub exception_handler {
   my ($self, $req, $e) = @_; my $msg = "${e}"; chomp $msg;

   return { code => $e->rv, content => { message => $msg }, view => 'json', };
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

Copyright (c) 2015 Peter Flanigan. All rights reserved

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
