# @(#)$Ident: UserRole.pm 2013-11-18 16:42 pjf ;

package App::MCP::Schema::Schedule::Result::UserRole;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.3.%d', q$Rev: 10 $ =~ /\d+/gmx );
use parent                  qw( App::MCP::Schema::Base );

use App::MCP::Constants;

my $class = __PACKAGE__; my $result = 'App::MCP::Schema::Schedule::Result';

$class->table( 'user_role' );

$class->add_columns( user_id => $class->foreign_key_data_type,
                     role_id => $class->foreign_key_data_type, );

$class->set_primary_key( qw( user_id role_id ) );

$class->belongs_to( user => "${result}::User", 'user_id' );

$class->belongs_to( role => "${result}::Role", 'role_id' );

1;

__END__

=pod

=head1 Name

App::MCP::Schema::Schedule::Result::UserRole - <One-line description of module's purpose>

=head1 Version

This documents version v0.3.$Rev: 10 $

=head1 Synopsis

   use App::MCP::Schema::Schedule::Result::UserRole;
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

Copyright (c) 2013 Peter Flanigan. All rights reserved

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