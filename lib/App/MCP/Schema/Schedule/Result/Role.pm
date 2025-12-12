package App::MCP::Schema::Schedule::Result::Role;

use overload '""' => sub { $_[0]->_as_string },
             '+'  => sub { $_[0]->_as_number }, fallback => 1;

use App::MCP::Util qw( serial_data_type text_data_type );
use DBIx::Class::Moo::ResultClass;

extends 'App::MCP::Schema::Base';

my $class  = __PACKAGE__;
my $result = 'App::MCP::Schema::Schedule::Result';

$class->table('roles');

$class->add_columns(
   id        => { %{serial_data_type()}, label => 'Role ID' },
   role_name => text_data_type(),
);

$class->set_primary_key('id');

$class->add_unique_constraint('roles_role_name_uniq', ['role_name']);

$class->has_many('users' => "${result}::User", 'role_id');

# Private methods
sub _as_number {
   return $_[0]->id;
}

sub _as_string {
   return $_[0]->role_name;
}

1;

__END__

=pod

=head1 Name

App::MCP::Schema::Schedule::Result::Role - <One-line description of module's purpose>

=head1 Synopsis

   use App::MCP::Schema::Schedule::Result::Role;
   # Brief but working code examples

=head1 Description

=head1 Configuration and Environment

=head1 Subroutines/Methods

=head1 Diagnostics

=head1 Dependencies

=over 3

=item L<Class::Usul>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module.
Please report problems to the address below.
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
