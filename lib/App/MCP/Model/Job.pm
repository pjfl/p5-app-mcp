package App::MCP::Model::Job;

use App::MCP::Constants    qw( CRONTAB_FIELD_NAMES EXCEPTION_CLASS
                               NUL SEPARATOR SPC TRUE );
use HTTP::Status           qw( HTTP_EXPECTATION_FAILED );
use App::MCP::Util         qw( redirect redirect2referer strip_parent_name );
use Unexpected::Functions  qw( throw UnknownJob Unspecified );
use Web::Simple;
use App::MCP::Attributes;  # Will do cleaning

extends 'App::MCP::Model';
with    'Web::Components::Role';

has '+moniker' => default => 'job';

# Public methods
sub base : Auth('view') {
   my ($self, $context, $jobid) = @_;

   my $nav = $context->stash('nav')->list('job')->item('job/create');

   if ($jobid) {
      my $job = $context->model('Job')->find($jobid);

      return $self->error($context, UnknownJob, [$jobid]) unless $job;

      $context->stash(job => $job);
      $nav->crud('job', $jobid);
   }

   $nav->finalise;
   return;
}

sub create : Nav('Create Job') {
   my ($self, $context) = @_;

   my $options = { context => $context, title => 'Create Job' };
   my $form    = $self->new_form('Job', $options);

   if ($form->process(posted => $context->posted)) {
      my $view    = $context->uri_for_action('job/view', [$form->item->id]);
      my $message = ['Job [_1] created', $form->item->job_name];

      $context->stash(redirect $view, $message);
   }

   $context->stash(form => $form);
   return;
}

sub delete : Nav('Delete Job') {
   my ($self, $context, $jobid) = @_;

   return unless $context->verify_form_post;

   my $job = $context->stash('job');

   return $self->error($context, UnknownJob, [$jobid]) unless $job;

   my $name = $job->job_name;

   $job->delete;

   my $list = $context->uri_for_action('job/list');

   $context->stash(redirect $list, ['Job [_1] deleted', $name]);
   return;
}

sub edit : Nav('Edit Job') {
   my ($self, $context) = @_;

   my $job  = $context->stash('job');
   my $options = {context => $context, item => $job, title => 'Edit job'};
   my $form    = $self->new_form('Job', $options);

   if ($form->process(posted => $context->posted)) {
      my $view = $context->uri_for_action('job/view', [$job->jobid]);
      my $message = ['Job [_1] updated', $form->item->job_name];

      $context->stash(redirect $view, $message);
   }

   $context->stash(form => $form);
   return;
}

sub list : Auth('view') Nav('Jobs|img/job.svg') {
   my ($self, $context) = @_;

   my $options = { context => $context };

   if (my $list_id = $context->request->query_parameters->{list_id}) {
      $options->{list_id} = $list_id;
   }

   $context->stash(table => $self->new_table('Job', $options));
   return;
}

sub remove {
   my ($self, $context) = @_;

   return unless $context->verify_form_post;

   my $value = $context->request->body_parameters->{data} or return;
   my $rs    = $context->model('Job');
   my $count = 0;

   for my $job (grep { $_ } map { $rs->find($_) } @{$value->{selector}}) {
      $job->delete;
      $count++;
   }

   $context->stash(redirect2referer $context, ["${count} job(s) deleted"]);
   return;
}

sub view : Auth('view') Nav('View Job') {
   my ($self, $context) = @_;

   my $job     = $context->stash('job');
   my $options = { caption => 'Job View', context => $context, result => $job };

   $context->stash(table => $self->new_table('Object::View', $options));
   return;
}



# TODO: Old job model methods parked here
sub choose_action : Role(any) {
   my ($self, $req) = @_; my $job;

   my $job_rs = $self->schema->resultset( 'Job' );
   my $idorn  = join SEPARATOR, @{ $req->uri_params->( { optional => TRUE } ) };

   if ($idorn) { $job = $job_rs->find_by_id_or_name( $idorn ) }
   else {
      my $where = { name => $req->body_params->( 'name', { raw => TRUE } ) };

      $job = $job_rs->search( $where, { columns => [ 'id' ] } )->first;
   }

   my $id; $job and $id = $job->id;

   return { redirect => { location => $req->uri_for( 'job', [ $id ] ) } };
}

sub chooser : Role(any) {
   my ($self, $req) = @_;

   my $opts    = { scrubber => '[^ \%\*+\-\./0-9@A-Z\\_a-z~]' };
   my $chooser = $self->build_chooser( $req, $opts );
   my $page    = { meta => delete $chooser->{meta} };
   my $stash   = $self->get_stash( $req, $page, 'job_chooser' => $chooser );

   $stash->{view} = 'json';
   return $stash;
}

sub chooser_rows : Role(any) {
   my ($self, $req) = @_;

   my $opts  = { form   => 'job',
                 method => '_job_chooser_link_hash',
                 values => $self->_job_chooser_search( $req ) };
   my $rows  = $self->build_chooser_rows( $req, $opts );
   my $page  = { meta => delete $rows->{meta} };
   my $stash = $self->get_stash( $req, $page, 'job_grid_rows' => $rows );

   $stash->{view} = 'json';
   return $stash;
}

sub chooser_table : Role(any) {
   my ($self, $req) = @_;

   my $params  = $req->query_params;
   my $value   = $params->( 'field_value', { optional => TRUE } ) || '%';
   my $total   = $self->schema->resultset( 'Job' )
      ->search( { id => { '>' => 1 }, name => { -like => $value } } )
      ->count;
   my $opts    = {
      form     => 'job',
      label    => 'Job names',
      scrubber => '[^ \%\*+\-\./0-9@A-Z\\_a-z~]',
      total    => $total, };
   my $table   = $self->build_chooser_table( $req, $opts );
   my $page    = { meta => delete $table->{meta} };
   my $stash   = $self->get_stash( $req, $page, 'job_grid_table' => $table );

   $stash->{view} = 'json';
   return $stash;
}

sub clear_action : Role(any) {
   return { redirect => { location => $_[ 1 ]->uri_for( 'job' ) } };
}

sub job_state : Role(any) {
   my ($self, $req) = @_;

   my $sep       = SEPARATOR;
   my $form      = 'job_state_dialog';
   my $idorn     = join $sep, @{ $req->uri_params->( { optional => TRUE } ) };
   my $rs        = $self->schema->resultset( 'JobState' );
   my $job_state = $rs->find_by_id_or_name( $idorn );
   my $page      = { meta => { id => $req->query_params->( 'id' ) } };
   my $stash     = $self->get_stash( $req, $page, $form => $job_state );

   $stash->{view} = 'json';
   return $stash;
}

# Private methods
sub  _job_chooser_assign_hook {
   return $_[ 1 ]->uri_for( 'job_chooser' );
}

sub _job_chooser_link_hash {
   return { href => '#top',           text  => $_[ 3 ]->job_name,
            tip  => $_[ 3 ]->summary, value => $_[ 3 ]->job_name, };
}

sub _job_chooser_search {
   my ($self, $req) = @_; my $params = $req->query_params;

   my $opts  = { optional => TRUE, scrubber => '[^ \%\*+\-\./0-9@A-Z\\_a-z~]' };
   my $value = $params->( 'field_value', $opts ) || '%';

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

   return $self->schema->resultset( 'Job' )->find( $row->parent_id )->job_name;
}

1;

__END__

=pod

=encoding utf-8

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
