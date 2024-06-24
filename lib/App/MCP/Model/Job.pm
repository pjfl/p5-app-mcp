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
      my $job = $context->model('Job')->find_by_key($jobid);

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

   return unless $self->verify_form_post($context);

   my $job  = $context->stash('job');
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

   if ($form->process(posted => $context->posted)) {
      my $view    = $context->uri_for_action('job/view', [$job->jobid]);
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

   my $options = { context => $context, result => $context->stash('job') };

   $context->stash(table => $self->new_table('Job::View', $options));
   return;
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
