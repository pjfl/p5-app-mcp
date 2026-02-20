package App::MCP::Model::State;

use App::MCP::Constants          qw( EXCEPTION_CLASS FALSE NUL TRUE );
use Unexpected::Types            qw( Int );
use App::MCP::Util               qw( redirect );
use Web::ComposableRequest::Util qw( bson64id bson64id_time );
use Unexpected::Functions        qw( throw UnknownJob );
use Try::Tiny;
use Moo;
use App::MCP::Attributes;

extends 'App::MCP::Model';
with    'Web::Components::Role';

has '+moniker' => default => 'state';

has 'default_path_depth' => is => 'ro', isa => Int, default => 3;

has 'dom_wait' => is => 'ro', isa => Int, default => 500;

# Hard limit on the number of jobs to fetch from the database
has 'max_jobs' => is => 'ro', isa => Int, default => 10_000;

# Public methods
sub base : Auth('view') {
   my ($self, $context, $jobid) = @_;

   my $nav = $context->stash('nav')->list('job')->item('job/create');

   if ($jobid) {
      my $job = $context->model('Job')->find($jobid, { prefetch => 'state' });

      return $self->error($context, UnknownJob, [$jobid]) unless $job;

      $context->stash(job => $job);
   }

   $nav->finalise;
   return;
}

sub edit  {
   my ($self, $context) = @_;

   my $job  = $context->stash->{job};
   my $form = $self->new_form('State', { context => $context, item => $job });

   if ($form->process(posted => $context->posted)) {
      my $view    = $context->uri_for_action('state/view');
      my $message = [
         'Job [_1] event transition [_2] created',
         $job->job_name,
         $form->field('signal')->value
      ];

      $context->stash(redirect $view, $message);
   }

   $context->stash(form => $form);
   return;
}

sub view : Auth('view') Nav('State|info') {
   my ($self, $context) = @_;

   my $req_params = $context->request->query_parameters;

   if (($req_params->{'state-data'} // NUL) eq 'true') {
      my $tree = $self->_get_job_tree($context, $req_params);

      $context->stash(json => $tree, view => 'json')
         unless $context->stash->{finalised};

      return;
   }

   my $params    = { 'state-data' => 'true' };
   my $data_uri  = $context->uri_for_action('state/view', [], $params);
   my $wcom      = $self->config->wcom_resources->{navigation};
   my $name      = 'state-diagram';
   my $prefs_uri = $context->uri_for_action('api/preference', [$name]);

   $context->stash(state_config => {
      'data-uri'     => $data_uri->as_string,
      'dom-wait'     => $self->dom_wait,
      'icons'        => $context->icons_uri->as_string,
      'max-jobs'     => $self->max_jobs,
      'name'         => $name,
      'onload'       => "${wcom}.onContentLoad()",
      'prefs-uri'    => $prefs_uri->as_string,
      'verify-token' => $context->verification_token,
   });
   return;
}

# Private methods
sub _add_node {
   my ($self, $nodes, $job, $item) = @_;

   $nodes->[$job->parent_id] //= [] if $job->parent_id;

   if ($job->type eq 'box') {
      $item->{'nodes'} = $nodes->[$job->id] //= [];
   }

   my $list = $job->parent_id ? $nodes->[$job->parent_id] : $nodes->[0];

   push @{$list}, $item;
   return;
}

sub _fetch_jobs {
   my ($self, $params) = @_;

   my $where = $self->_get_where_clause($params);
   my $jobs  = $self->schema->resultset('Job')->search($where, {
      columns  => [
         qw( condition dependencies id job_name parent_id path_depth type )
      ],
      order_by => [\q{parent_id NULLS FIRST}, 'id'],
      prefetch => ['state'],
      rows     => $self->max_jobs,
   });

   return [$jobs->all];
}

sub _get_job_item {
   my ($self, $context, $job) = @_;

   my $uri = $context->uri_for_action('state/edit', [$job->id]);

   return {
      'depends-on' => [split m{ / }mx, $job->dependencies // NUL],
      'id'         => $job->id,
      'job-name'   => $job->job_name,
      'job-uri'    => $uri->as_string,
      'parent-id'  => $job->parent_id,
      'path-depth' => $job->path_depth,
      'state-name' => $job->state->name,
      'type'       => $job->type,
   };
}

sub _get_job_tree {
   my ($self, $context, $params) = @_;

   my $all_jobs   = $self->_fetch_jobs($params);
   my $jobs2go    = scalar @{$all_jobs};
   my $nodes      = [[]];
   my $seen       = {};
   my $job_count  = 0;
   my $loop_count = 0;

   try {
      while (my $job = shift @{$all_jobs}) {
         my $item = $self->_get_job_item($context, $job);

         if ($self->_have_seen_dependencies($seen, $item)) {
            $self->_add_node($nodes, $job, $item);
            $seen->{$job->id} = TRUE;
            $job_count++;
         }
         else { push @{$all_jobs}, $job }

         if (++$loop_count >= $jobs2go) { # Prevent infinite looping
            if ($jobs2go == scalar @{$all_jobs}) {
               throw 'Dependencies not found';
            }
            else {
               $jobs2go = scalar @{$all_jobs};
               $loop_count = 0;
            }
         }
      }
   }
   catch { $self->error($context, $_) };

   my $node_id = $params->{selected} ? $params->{selected} : 0;

   return { 'job-count' => $job_count, 'jobs' => $nodes->[$node_id] };
}

sub _get_where_clause {
   my ($self, $params) = @_;

   my $depth = $params->{'path-depth'} || $self->default_path_depth;

   return { path_depth => { '<=' => $depth } } unless $params->{selected};

   return {
      parent_id  => $params->{selected},
      path_depth => { '<=' => $depth + $self->default_path_depth },
   };
}

sub _have_seen_dependencies {
   my ($self, $seen, $item) = @_;

   for my $job_id (@{$item->{'depends-on'}}) {
      return FALSE unless $seen->{$job_id};
   }

   return TRUE;
}

1;

__END__

=pod

=encoding utf8

=head1 Name

App::MCP::Model::State - One-line description of the modules purpose

=head1 Synopsis

   use App::MCP::Model::State;
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
