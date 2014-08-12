package App::MCP::Model::API;

use namespace::autoclean;

use Moo;
use App::MCP::Constants    qw( NUL );
use App::MCP::Functions    qw( trigger_input_handler );
use Class::Usul::Functions qw( bson64id bson64id_time throw );
use Class::Usul::Time      qw( time2str );
use Class::Usul::Types     qw( Object );
use HTTP::Status           qw( HTTP_BAD_REQUEST HTTP_CREATED
                               HTTP_NOT_FOUND   HTTP_OK );
use JSON                   qw( );
use Try::Tiny;

extends q(App::MCP::Model);

# Private attributes
has '_transcoder' => is => 'lazy', isa => Object, builder => sub { JSON->new },
   reader         => 'transcoder';

with q(App::MCP::Role::APIAuthentication);

# Public methods
sub create_event {
   my ($self, $req) = @_; my $event; $req->authenticate;

   my $schema = $self->schema;
   my $run_id = $req->params->{runid} // 'undef';
   my $pe_rs  = $schema->resultset( 'ProcessedEvent' )
                       ->search( { runid   => $run_id },
                                 { columns => [ 'token' ] } );
   my $pevent = $pe_rs->first
      or throw error => 'Runid [_1] not found',
               args  => [ $run_id ], rv => HTTP_NOT_FOUND;
   my $params = $self->authenticate_params
      ( $run_id, $pevent->token, $req->body->param->{event} );

   try   { $event = $schema->resultset( 'Event' )->create( $params ) }
   catch { throw error => $_, rv => HTTP_BAD_REQUEST };

   trigger_input_handler $ENV{MCP_DAEMON_PID};

   return { code    => HTTP_CREATED,
            content => { message => 'Event '.$event->id.' created' } };
}

sub create_job {
   my ($self, $req) = @_; my $job; $req->authenticate;

   my $sess   = $self->get_session( $req->params->{sessionid} // 'undef' );
   my $params = $self->authenticate_params
      ( $sess->{key}, $sess->{shared_secret}, $req->body->param->{job} );

   $params->{owner_id} = $sess->{user_id};
   $params->{group_id} = $sess->{role_id};

   try   { $job = $self->schema->resultset( 'Job' )->create( $params ) }
   catch { throw error => $_, rv => HTTP_BAD_REQUEST };

   return { code    => HTTP_CREATED,
            content => { message => 'Job '.$job->id.' created' } };
}

sub exception_handler {
   my ($self, $req, $e) = @_; my $msg = "${e}"; chomp $msg;

   return { code => $e->rv, content => { message => $msg } };
}

sub snapshot_state {
   my ($self, $req) = @_;

   my $frames = [];
   my $id     = bson64id;
   my $schema = $self->schema;
   my $level  = $req->params->{level} // 1;
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
   catch { throw error => $_, rv => HTTP_BAD_REQUEST };

   my $minted  = time2str undef, bson64id_time( $id );
   my $content = { id => $id, jobs => $frames, minted => $minted };

   return { code => HTTP_OK, content => $content };
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
