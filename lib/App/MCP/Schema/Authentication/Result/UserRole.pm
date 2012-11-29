# @(#)$Id$

package App::MCP::Schema::Authentication::Result::UserRole;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );
use parent qw(App::MCP::Schema::Base);

use Class::Usul::Constants;

my $class = __PACKAGE__; my $schema = 'App::MCP::Schema::Authentication';

$class->table( 'user_role' );

$class->add_columns
   ( user_id => { data_type     => 'integer',
                  default_value => undef,
                  extra         => { unsigned => TRUE },
                  is_nullable   => FALSE, },
     role_id => { data_type     => 'integer',
                  default_value => undef,
                  extra         => { unsigned => TRUE },
                  is_nullable   => FALSE, }, );

$class->set_primary_key( qw(user_id role_id) );

$class->belongs_to( user_rel => "${schema}::Result::User", 'user_id' );

$class->belongs_to( role_rel => "${schema}::Result::Role", 'role_id' );

1;

__END__

=pod

=head1 Name

App::MCP::Schema::Authentication::Result::UserRole - <One-line description of module's purpose>

=head1 Version

0.1.$Revision$

=head1 Synopsis

   use App::MCP::Schema::Authentication::Result::UserRole;
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
