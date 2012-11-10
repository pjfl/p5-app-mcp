# @(#)$Id$

package App::MCP::Schema::Authentication::Result::Role;

use strict;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use Class::Usul::Moose;
use Class::Usul::Constants;

extends qw(App::MCP::Schema::Base);

__PACKAGE__->table( 'role' );
__PACKAGE__->add_columns( 'id',   { data_type         => 'MEDIUMINT',
                                    default_value     => undef,
                                    is_auto_increment => TRUE,
                                    is_nullable       => FALSE,
                                    size              => 8, },
                          'desc', { data_type         => 'VARCHAR',
                                    default_value     => NUL,
                                    is_nullable       => FALSE,
                                    size              => 255, } );
__PACKAGE__->set_primary_key( 'id' );
__PACKAGE__->add_unique_constraint([ 'desc' ]);
__PACKAGE__->has_many(
   users => 'App::MCP::Schema::Authentication::Result::UserRole', 'role_id' );

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=head1 Name

App::MCP::Schema::Authentication::Result::Role - <One-line description of module's purpose>

=head1 Version

0.1.$Revision$

=head1 Synopsis

   use App::MCP::Schema::Authentication::Result::Role;
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

Peter Flanigan, C<< <Support at RoxSoft dot co dot uk> >>

=head1 License and Copyright

Copyright (c) 2012 Peter Flanigan. All rights reserved

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
