package App::MCP::Model::Job;

use App::MCP::Constants    qw( EXCEPTION_CLASS FALSE NUL TRUE );
use Unexpected::Types      qw( HashRef );
use App::MCP::Util         qw( redirect redirect2referer );
use Unexpected::Functions  qw( UnauthorisedAccess UnknownJob );
use Moo;
use App::MCP::Attributes;  # Will do cleaning

extends 'App::MCP::Model';
with    'Web::Components::Role';

has '+moniker' => default => 'job';

has 'role_map' => is => 'ro', isa => HashRef, default => sub { {} };

# Public methods
sub base : Auth('view') {
   my ($self, $context) = @_;

   $context->stash('nav')->list('job')->item('job/create')->finalise;
   return;
}

sub jobid : Auth('view') Capture(1) {
   my ($self, $context, $jobid) = @_;

   my $options = { prefetch => [qw(parent_box owner_rel group_rel)] };
   my $job     = $context->model('Job')->find_by_key($jobid, $options);

   return $self->error($context, UnknownJob, [$jobid]) unless $job;

   my $role_id  = $self->_get_role_id($context);
   my $identity = { owner => $context->session->id, group => $role_id };

   return $self->error($context, UnauthorisedAccess)
      unless $job->is_readable_by($identity);

   $context->stash(job => $job);

   my $nav = $context->stash('nav')->list('job')->item('job/create');

   $nav->crud('job', $job->id)->finalise;
   return;
}

sub create : Nav('Create Job') {
   my ($self, $context) = @_;

   my $options = { context => $context };
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
   my ($self, $context) = @_;

   return unless $self->verify_form_post($context);

   my $job = $context->stash('job');

   return $self->error($context, UnauthorisedAccess)
      unless $self->_can_update($context, $job);

   my $name = $job->job_name;

   $job->delete;

   my $list = $context->uri_for_action('job/list');

   $context->stash(redirect $list, ['Job [_1] deleted', $name]);
   return;
}

sub edit : Nav('Edit Job') {
   my ($self, $context) = @_;

   my $job     = $context->stash('job');
   my $options = { context => $context, item => $job, title => 'Edit job' };
   my $form    = $self->new_form('Job', $options);

   return $self->error($context, UnauthorisedAccess)
      if $context->posted && !$self->_can_update($context, $job);

   if ($form->process(posted => $context->posted)) {
      my $view    = $context->uri_for_action('job/view', [$job->id]);
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

   return unless $self->verify_form_post($context);

   my $value = $context->body_parameters->{data} or return;
   my $rs    = $context->model('Job');
   my $names = [];

   for my $job (grep { $_ } map { $rs->find($_) } @{$value->{selector}}) {
      return $self->error($context, UnauthorisedAccess)
         unless $self->_can_update($context, $job);

      push @{$names}, $job->job_name;
      $job->delete;
   }

   my $message = ['Job(s) [_1] deleted', (join ', ', @{$names}) ];

   $context->stash(redirect2referer $context, $message);
   return;
}

sub select {
   my ($self, $context) = @_;

   my $options  = { context => $context };
   my $params   = $context->request->query_parameters;
   my $selected = $params->{selected};

   $options->{configurable} = FALSE;
   $options->{caption}      = NUL;
   $options->{selected}     = $selected if $selected;
   $options->{selectonly}   = TRUE;

   $context->stash(table => $self->new_table('BoxSelector', $options));
   return;
}

sub view : Auth('view') Nav('View Job') {
   my ($self, $context) = @_;

   my $options = { context => $context, result => $context->stash('job') };

   $context->stash(table => $self->new_table('View::Job', $options));
   return;
}

# Private methods
sub _can_update {
   my ($self, $context, $job) = @_;

   my $session  = $context->session;
   my $role     = $session->role || NUL;
   my $role_id  = $self->_get_role_id($context);
   my $identity = { owner => $session->id, group => $role_id };

   return FALSE if $role eq 'view';
   return TRUE  if $role eq 'admin' || $role eq 'manager';
   return TRUE  if $job->is_writable_by($identity);
   return FALSE;
}

sub _get_role_id {
   my ($self, $context) = @_;

   my $role_name = $context->session->role or return 0;

   return $self->role_map->{$role_name} if exists $self->role_map->{$role_name};

   my $role = $context->model('Role')->find_by_key($role_name);

   $self->role_map->{$role_name} = $role->id if $role;

   return $role ? $role->id : 0;
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

Copyright (c) 2025 Peter Flanigan. All rights reserved

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
