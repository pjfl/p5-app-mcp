package App::MCP::Model::Root;

use App::MCP::Attributes; # Will do cleaning
use App::MCP::ConfigEditor;
use App::MCP::Constants qw( FALSE NUL TRUE );
use Class::Usul::Types  qw( Object );
use HTTP::Status        qw( HTTP_NOT_FOUND );
use Moo;

extends 'App::MCP::Model';
with    'App::MCP::Role::PageConfiguration';
with    'App::MCP::Role::WebAuthentication';
with    'Web::Components::Role::Forms';

has '+moniker' => default => 'root';

has 'config_editor' => is => 'lazy', isa => Object, builder => sub {
   App::MCP::ConfigEditor->new( builder => $_[ 0 ]->application ) };

sub check_field : Role(anon) {
   my ($self, $req) = @_;

   return $self->check_form_field( $req, $self->schema_class.'::Result' );
}

sub config_form : Role(any) {
   my ($self, $req) = @_;

   my $title = $req->loc( 'Configuration' );
   my $page  = { action => $req->uri, form_name => 'config', title => $title, };
   my $data  = { values => { data => $self->config_editor->config_data }, };

   return $self->get_stash( $req, $page, config => $data );
}

sub login_action : Role(anon) {
   my ($self, $req) = @_;

   my $params   = $req->body_params;
   my $username = $params->( 'username' );
   my $user     = $self->schema->resultset( 'User' )->find_by_name( $username );

   $user->authenticate( $params->( 'password' ) ); # Throws on failure

   my $sess     = $req->session; my $primary = $user->primary_role.NUL;

   $sess->authenticated( TRUE );
   $sess->username     ( $username );
   $sess->user_roles   ( [ $primary, @{ $user->list_other_roles } ] );

   my $wanted   = $sess->wanted || 'job'; $sess->wanted( NUL );
   my $location = $req->uri_for( $wanted );
   my $message  = [ 'User [_1] logged in', $username ];

   return { redirect => { location => $location, message => $message } };
}

sub login_form : Role(anon) {
   my ($self, $req) = @_;

   my $title = $req->loc( 'Login' );
   my $idorn = $req->uri_params->( 0, { optional => TRUE } );
   my $user  = $self->schema->resultset( 'User' )->find_by_id_or_name( $idorn );
   my $page  = { action => $req->uri, form_name => 'login', title => $title, };

   return $self->get_stash( $req, $page, login => $user );
}

sub logout_action : Role(any) {
   my ($self, $req) = @_; $req->session->authenticated( FALSE );

   my $location = $req->uri_for( 'login' );
   my $message  = [ 'User [_1] logged out', $req->username ];

   return { redirect => { location => $location, message => $message } };
}

my $nav_cache = {};

sub navigator : Role(anon) {
   my ($self, $req) = @_; my $data;

   unless ($data = $nav_cache->{ $req->locale }) {
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

      $nav_cache->{ $req->locale } = $data;
   }

   my $page  = { meta => { id    => 'nav_panel' } };
   my $list  = { list => { class => 'nav_list', data => $data } };
   my $stash = $self->get_stash( $req, $page, nav => $list );

   $stash->{view} = 'json';
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
