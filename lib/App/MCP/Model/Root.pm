package App::MCP::Model::Root;

use feature 'state';

use Moo;
use App::MCP::Attributes;
use App::MCP::Constants qw( FALSE NUL TRUE );
use HTTP::Status        qw( HTTP_NOT_FOUND );

extends q(App::MCP::Model);
with    q(App::MCP::Role::CommonLinks);
with    q(App::MCP::Role::JavaScript);
with    q(App::MCP::Role::PageConfiguration);
with    q(App::MCP::Role::Preferences);
with    q(App::MCP::Role::FormBuilder);
with    q(App::MCP::Role::WebAuthentication);

has '+moniker' => default => 'root';

sub login_action : Role(anon) {
   my ($self, $req) = @_;

   my $params   = $req->body_params;
   my $username = $params->( 'username' );
   my $user     = $self->schema->resultset( 'User' )->find_by_name( $username );

   $user->authenticate( $params->( 'password' ) );

   my $session  = $req->session; my $primary = NUL.$user->primary_role;

   $session->authenticated( TRUE );
   $session->username     ( $username );
   $session->user_roles   ( [ $primary, @{ $user->list_other_roles } ] );

   my $location = $req->uri_for( 'job' );
   my $message  = [ 'User [_1] logged in', $username ];

   return { redirect => { location => $location, message => $message } };
}

sub login_form : Role(anon) {
   my ($self, $req) = @_;

   my $arg   = $req->args->[ 0 ];
   my $title = $req->loc( 'Login' );
   my $page  = { action => $req->uri, form_name => 'login', title => $title, };
   my $user  = $self->schema->resultset( 'User' )->find_by_id_or_name( $arg );

   return $self->get_stash( $req, $page, login => $user );
}

sub logout_action : Role(any) {
   my ($self, $req) = @_; $req->session->authenticated( FALSE );

   my $location = $req->uri_for( 'login' );
   my $message  = [ 'User [_1] logged out', $req->username ];

   return { redirect => { location => $location, message => $message } };
}

sub navigator : Role(anon) {
   my ($self, $req) = @_; state $cache = {}; my $data;

   unless ($data = $cache->{ $req->locale }) {
      my $opts = { no_default => TRUE }; $data = [];

      for my $action (@{ $self->config->nav_list }) {
         my $text = $req->loc( "${action}_nav_link_text", $opts )
                 || ucfirst $action;
         my $tip  = $req->loc( "${action}_nav_link_tip",  $opts )
                 || $req->loc( 'Goto this page in the application' );
         my $href = $req->uri_for( $action );

         push @{ $data }, { content => {
            container => FALSE, href => $href,    text   => $text,
            tip       => $tip,  type => 'anchor', widget => TRUE } };
      }

      $cache->{ $req->locale } = $data;
   }

   my $list  = { list => { class => 'nav_list', data => $data } };
   my $page  = { meta => { id    => 'nav_panel' } };
   my $stash = $self->get_stash( $req, $page, nav => $list );

   $stash->{view} = 'xml';
   return $stash;
}

sub not_found : Role(anon) {
   my ($self, $req) = @_;

   my $page = { code  => HTTP_NOT_FOUND,
                error => $req->loc( 'Resource [_1] not found', $req->uri ),
                title => $req->loc( 'Not found' ) };

   return $self->get_stash( $req, $page, exception => {} );
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
