package App::MCP::Model::Job;

use App::MCP::Attributes;  # Will do cleaning
use App::MCP::Constants    qw( CRONTAB_FIELD_NAMES EXCEPTION_CLASS
                               NUL SPC TRUE );
use App::MCP::Util         qw( strip_parent_name );
use HTTP::Status           qw( HTTP_EXPECTATION_FAILED );
use Unexpected::Functions  qw( throw Unspecified );
use Moo;

extends 'App::MCP::Model';
with    'App::MCP::Role::PageConfiguration';
with    'App::MCP::Role::FormBuilder';
with    'App::MCP::Role::WebAuthentication';

has '+moniker' => default => 'job';

# Private functions
my $_job_not_found = sub {
   return { redirect    => {
               location => $_[ 0 ]->uri_for( 'job' ),
               message  => [ 'Job id [_1] not found', $_[ 1 ] ] } };
};

# Public methods
sub choose_action : Role(any) {
   my ($self, $req) = @_;

   my $job_rs   = $self->schema->resultset( 'Job' );
   my $where    = { name => $req->body_params->( 'name', { raw => TRUE } ) };
   my $job      = $job_rs->search( $where, { columns => [ 'id' ] } )->first;
   my $location = $req->uri_for( 'job', [ $job ? $job->id : undef ] );

   return { redirect => { location => $location } };
}

sub chooser : Role(any) {
   my ($self, $req) = @_;

   my $chooser = $self->build_chooser( $req );
   my $page    = { meta => delete $chooser->{meta} };
   my $stash   = $self->get_stash( $req, $page, 'job_chooser' => $chooser );

   $stash->{view} = 'json';
   return $stash;
}

sub clear_action : Role(any) {
   return { redirect => { location => $_[ 1 ]->uri_for( 'job' ) } };
}

sub delete_action : Role(any) {
   my ($self, $req) = @_;

   my $idorn    = $req->uri_params->( 0 );
   my $location = $req->uri_for( 'job' );
   my $message  = [ 'Job [_1] not found', $idorn ];
   my $job_rs   = $self->schema->resultset( 'Job' );
   my $job      = $job_rs->find_by_id_or_name( $idorn )
      or return { redirect => { location => $location, message => $message } };
   my $name     = $job->name; $job->delete;

   $message = [ 'Job name [_1] deleted', $name ];

   return { redirect => { location => $location, message => $message } };
}

sub definition_form : Role(any) {
   my ($self, $req) = @_;

   my $title = $req->loc( 'Job Definition' );
   my $idorn = $req->uri_params->( 0, { optional => TRUE } );
   my $job   = $self->schema->resultset( 'Job' )->find_by_id_or_name( $idorn );
   my $page  = { action => $req->uri, form_name => 'job', title => $title, };

   $job and $page->{job_id} = $job->id;

   return $self->get_stash( $req, $page, 'job' => $job );
}

sub grid_rows : Role(any) {
   my ($self, $req) = @_;

   my $args  = { form   => 'job',
                 method => '_job_chooser_link_hash',
                 values => $self->_job_chooser_search( $req ) };
   my $rows  = $self->build_grid_rows( $req, $args );
   my $page  = { meta => delete $rows->{meta} };
   my $stash = $self->get_stash( $req, $page, 'job_grid_rows' => $rows );

   $stash->{view} = 'json';
   return $stash;
}

sub grid_table : Role(any) {
   my ($self, $req) = @_; my $args = {}; my $params = $req->query_params;

   my $field_value  = $params->( 'field_value', { optional => TRUE } ) || '%';

   $args->{form } = 'job';
   $args->{label} = 'Job names';
   $args->{total} = $self->schema->resultset( 'Job' )
                         ->search( { id   => { '>' => 1 },
                                     name => { -like => $field_value } } )
                         ->count;

   my $table = $self->build_grid_table( $req, $args );
   my $page  = { meta => delete $table->{meta} };
   my $stash = $self->get_stash( $req, $page, 'job_grid_table' => $table );

   $stash->{view} = 'json';
   return $stash;
}

sub job_state : Role(any) {
   my ($self, $req) = @_;

   my $form      = 'job_state_dialog';
   my $idorn     = $req->uri_params->( 0 );
   my $rs        = $self->schema->resultset( 'JobState' );
   my $job_state = $rs->find_by_id_or_name( $idorn );
   my $page      = { meta => { id => $req->query_params->( 'id' ) } };
   my $stash     = $self->get_stash( $req, $page, $form => $job_state );

   $stash->{view} = 'json';
   return $stash;
}

sub save_action : Role(any) {
   my ($self, $req) = @_; my $job; my $message;

   my $idorn = $req->uri_params->( 0, { optional => TRUE } );
   my $args  = { id     => $idorn,
                 method => '_job_deflate_',
                 params => $req->body_params,
                 rs     => $self->schema->resultset( 'Job' ) };

   if (defined $idorn and length $idorn) {
      $job = $self->find_and_update_record( $args )
          or return $_job_not_found->( $req, $idorn );
      $message = [ 'Job [_1] updated', $job->name ];
   }
   else {
      $job = $self->create_record( $args, 'parent_name' );
      $message = [ 'Job [_1] created', $job->name ];
   }

   my $location = $req->uri_for( 'job', [ $job->id ] );

   return { redirect => { location => $location, message => $message } };
}

# Private methods
sub  _job_chooser_assign_hook {
   return $_[ 1 ]->uri_for( 'job_chooser' );
}

sub _job_chooser_link_hash {
   return { href => '#top',           text  => $_[ 3 ]->name,
            tip  => $_[ 3 ]->summary, value => $_[ 3 ]->name, };
}

sub _job_chooser_search {
   my ($self, $req) = @_; my $params = $req->query_params;

   my $args  = { optional => TRUE, scrubber => '[^ \%\*+\-\./0-9@A-Z\\_a-z~]' };
   my $value = $params->( 'field_value', $args ) || '%';

   return [ $self->schema->resultset( 'Job' )->search
            ( { id       => { '>' => 1 },
                name     => { -like => $value } },
              { order_by => 'name',
                page     => $params->( 'page' ) + 1,
                rows     => $params->( 'page_size' ) } )->all ];
}

sub _job_deflate_crontab {
   my $v = join SPC, map { $_[ 1 ]->( "crontab_${_}", {
      optional => TRUE } ) // NUL } CRONTAB_FIELD_NAMES;

   $v =~ s{ \A \s+ \z }{}mx; return $v;
}

sub _job_deflate_group {
   my $role_rs = $_[ 0 ]->schema->resultset( 'Role' );
   my $role    = $role_rs->find_by_name( $_[ 1 ]->( 'group_rel', {
      optional => TRUE } ) || 'unknown' );

   return $role ? $role->id : undef;
}

sub _job_deflate_owner {
   my $user_rs = $_[ 0 ]->schema->resultset( 'User' );
   my $user    = $user_rs->find_by_name( $_[ 1 ]->( 'owner_rel', {
      optional => TRUE } ) || 'unknown' );

   return $user ? $user->id : undef;
}

sub _job_deflate_parent_id {
   my $job_rs = $_[ 0 ]->schema->resultset( 'Job' );
   my $parent = $_[ 1 ]->( 'parent_name', { optional => TRUE } ) // NUL;
   my $owner  = $_[ 1 ]->( 'owner_rel',   { optional => TRUE } ) || 'unknown';

   return $job_rs->writable_box_id_by_name( $parent, $owner );
}

sub _job_deflate_permissions {
   my $perms = $_[ 1 ]->( 'permissions', { optional => TRUE } ) // NUL;

   return length $perms ? oct $perms : 0;
}

sub _job_name_assign_hook {
   my ($self, $req, $field, $row, $value) = @_; return strip_parent_name $value;
}

sub _job_parent_name_assign_hook {
   my ($self, $req, $field, $row, $value) = @_; $row or return $value;

   return $self->schema->resultset( 'Job' )->find( $row->parent_id )->name;
}

1;

__END__

=pod

=encoding utf8

=head1 Name

App::MCP::Model::Job - One-line description of the modules purpose

=head1 Synopsis

   use App::MCP::Model::Job;
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
