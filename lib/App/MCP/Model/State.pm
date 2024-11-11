package App::MCP::Model::State;

use App::MCP::Constants          qw( EXCEPTION_CLASS FALSE NUL TRUE );
use Web::ComposableRequest::Util qw( bson64id bson64id_time );
use Unexpected::Functions        qw( throw );
use Try::Tiny;
use Moo;
use App::MCP::Attributes;

extends 'App::MCP::Model';
with    'Web::Components::Role';

has '+moniker' => default => 'state';

# Public methods
sub base : Auth('view') {
   my ($self, $context) = @_;

   my $nav = $context->stash('nav')->list('job')->item('job/create');

   $nav->container_layout('left') if $context->endpoint eq 'view';

   $nav->finalise;
   return;
}

sub edit  {
   my ($self, $context) = @_;

   my $form = $self->new_form('State', { context => $context });

   if ($form->process(posted => $context->posted)) {
      my $view    = $context->uri_for_action('state/view');
      my $message = [''];

      $context->stash(redirect $view, $message);
   }

   $context->stash(form => $form);
   return;
}

sub view : Auth('view') Nav('State|info') {
   my ($self, $context) = @_;

   my $params = $context->request->query_parameters;

   if (($params->{'state-data'} // NUL) eq 'true') {
      my $tree = $self->_get_job_tree($context, $params);

      $context->stash(json => $tree, view => 'json')
         unless $context->stash->{finalised};

      return;
   }

   $params = { 'state-data' => 'true' };

   my $uri    = $context->uri_for_action('state/view', [], $params);
   my $config = { 'data-uri' => $uri->as_string };

   $context->stash(state_config => $config);
   return;
}

# Private methods
sub _get_job_tree {
   my ($self, $context, $params) = @_;

   # TODO: Use level to restrict rows in result
   my $level = $params->{level} // 1;
   my $jobs  = $self->schema->resultset('Job')->search({}, {
      'columns'  => [qw( id condition job_name parent_id type )],
      'order_by' => [\q{parent_id NULLS FIRST}, 'id'],
      'prefetch' => ['dependents', 'state'],
   });
   my $nodes = [[]];
   my $count = 0;

   try {
      for my $job ($jobs->all) {
         my $uri  = $context->uri_for_action('job/view', [$job->job_name]);
         my $item = {
            'depends'    => [ map { $_->reverse_id } $job->dependents->all ],
            'job-name'   => $job->job_name,
            'job-uri'    => $uri->as_string,
            'state-name' => $job->state->name,
            'type'       => $job->type,
         };

         $nodes->[$job->id] = $item->{'nodes'} = [] if $job->type eq 'box';

         my $list = $job->parent_id ? $nodes->[$job->parent_id] : $nodes->[0];

         push @{$list}, $item;
         $count++;
      }
   }
   catch { $self->error($context, $_) };

   return { 'job-count' => $count, jobs => $nodes->[0] };
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

Copyright (c) 2024 Peter Flanigan. All rights reserved

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
