package App::MCP::Model::State;

use App::MCP::Attributes;
use App::MCP::Constants    qw( EXCEPTION_CLASS NUL TRUE );
use Class::Usul::Functions qw( bson64id bson64id_time );
use HTTP::Status           qw( HTTP_BAD_REQUEST );
use Try::Tiny;
use Unexpected::Functions  qw( throw );
use Moo;

extends 'App::MCP::Model';
with    'Web::Components::Role';

has '+moniker' => default => 'state';

sub diagram : Role(any) {
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
   catch { throw $_, rv => HTTP_BAD_REQUEST };

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
