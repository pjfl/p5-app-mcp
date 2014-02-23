package App::MCP::Model::Root;

use namespace::sweep;

use Moo;
use App::MCP::Constants;
use Class::Usul::Functions qw( throw );

extends q(App::MCP::Model);
with    q(App::MCP::Role::CommonLinks);
with    q(App::MCP::Role::JavaScript);
with    q(App::MCP::Role::PageConfiguration);
with    q(App::MCP::Role::Preferences);
with    q(App::MCP::Role::FormBuilder);
with    q(App::MCP::Role::WebAuthentication);

sub authenticate_login : Role(any) {
   my ($self, $req) = @_;

   my $user_name    = $req->body->param->{username};
   my $user_rs      = $self->schema->resultset( 'User' );
   my $user         = $user_rs->find_by_name( $user_name );

   $user->authenticate( $req->body->param->{password} );

   my $session      = $req->session;
   my $location     = $req->uri_for( 'job' );
   my $primary_role = NUL.$user->primary_role;
   my $message      = [ 'User [_1] logged in', $user_name ];

   $session->{user_name } = $user_name;
   $session->{user_roles} = [ $primary_role, @{ $user->list_other_roles } ];

   return { redirect => { location => $location, message => $message } };
}

sub login_form : Role(any) {
   my ($self, $req) = @_;

   my $arg   = $req->args->[ 0 ];
   my $title = $req->loc( 'Login' );
   my $page  = { action => $req->uri, form_name => 'login', title => $title, };
   my $user  = $self->schema->resultset( 'User' )->find_by_id_or_name( $arg );

   return $self->get_stash( $req, $page, login => $user );
}

sub logout : Role(any) {
   my ($self, $req) = @_;

   my $session   = $req->session;
   my $user_name = $session->{user_name};
   my $location  = $req->uri_for( 'login' );
   my $message   = [ 'User [_1] logged out', $user_name ];

   delete $session->{user_name}; delete $session->{user_roles};

   return { redirect => { location => $location, message => $message } };
}

1;

__END__

=pod

=encoding utf8

=head1 Name

App::MCP::Model::Root - One-line description of the modules purpose

=head1 Synopsis

   use App::MCP::Model::Root;
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
