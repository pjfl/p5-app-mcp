package App::MCP::Table::Role;

use HTML::StateTable::Constants qw( FALSE NUL SPC TABLE_META TRUE );
use Moo;
use HTML::StateTable::Moo;

extends 'HTML::StateTable';
with    'HTML::StateTable::Role::CheckAll';
with    'HTML::StateTable::Role::Form';

=pod

=encoding utf-8

=head1 Name

App::MCP::Table::Role - Lists the collection of Role objects

=head1 Synopsis

   use App::MCP::Table::Role;

=head1 Description

Lists the collection of Role objects

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=cut

has '+caption' => default => 'List Roles';

has '+form_buttons' => default => sub {
   return [{
      action    => 'role/remove',
      class     => 'remove-item',
      selection => 'select_one',
      value     => 'Remove Role',
   }];
};

has '+form_control_location' => default => 'BottomRight';

has '+icons' => default => sub { shift->context->icons_uri->as_string };

has '+page_control_location' => default => 'TopLeft';

has '+page_size_control_location' => default => 'BottomLeft';

=back

=head1 Subroutines/Methods

Defineds the following methods;

=over 3

=cut

set_table_name 'user';

has_column 'role_name' =>
   label      => 'Role Name',
   link       => sub {
      my $self    = shift;
      my $context = $self->table->context;

      return  $context->uri_for_action('role/view', [$self->result->id]);
   },
   searchable => TRUE,
   sortable   => TRUE,
   title      => 'Sort by role',
   width      => '20rem';

has_column 'check' =>
   cell_traits => ['Checkbox'],
   label       => 'Select',
   value       => 'id';

use namespace::autoclean -except => TABLE_META;

1;

__END__

=back

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Moo>

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

Copyright (c) 2026 Peter Flanigan. All rights reserved

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
