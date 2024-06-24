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

   my $nav = $context->stash('nav')->list('job')->item('job/view');

   $nav->container_layout(NUL) if $context->endpoint eq 'view';

   $nav->finalise;
   return;
}

sub edit  {
   my ($self, $context) = @_;

   my $form = $self->new_form('State', { context => $context });

   if ($form->process(posted => $context->posted)) {
      my $view     = $context->uri_for_action('state/view');
      my $message  = [''];

      $context->stash(redirect $view, $message);
   }

   $context->stash(form => $form);
   return;
}

sub view : Auth('view') Nav('State') {
   my ($self, $context) = @_;

   $context->stash(state_config => {});
   return;
}

# Private methods
sub _get_job_tree {
   my ($self, $req) = @_;

   # TODO: Use level to restrict rows in result
   my $level  = $req->query_params->( 'level', { optional => TRUE } ) || 1;
   my $job_rs = $self->schema->resultset( 'Job' );
   my $jobs   = $job_rs->search( { id => { '>' => 1 } }, {
         'columns'  => [ qw( name id parent_id state.name type ) ],
         'join'     => 'state',
         'order_by' => [ 'parent_id', 'id' ], } );

   my $boxes = []; my $tree = {};

   try {
      for my $job ($jobs->all) {
         my $box   = $job->parent_id > 1 ? $boxes->[ $job->parent_id ] : $tree;
         my $item  = $box->{ $job->name } //= {};
         my $sname = $job->state->name;

         $box->{_keys} //= []; push @{ $box->{_keys} }, $job->name;
         $item->{_link_class} = "tree_link state-${sname} fade";
         $item->{_tip       } = "State: ${sname}";
         $item->{_url       } = 'job/'.$job->name;

         $job->type eq 'box' and $boxes->[ $job->id ] = $item;
      }
   }
   catch { throw $_ };

   my $id     = bson64id;
   my $page   = { minted => bson64id_time( $id ), title => 'State Diagram' };
   my $source = { state => { 'Schedule' => $tree }, };

   return $self->get_stash( $req, $page, diagram => $source );
}

sub _diagram_state_assign_hook {
   my ($self, $req, $field, $src, $value) = @_; return { data => $value };
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
