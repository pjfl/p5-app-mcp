# @(#)$Id$

package App::MCP::Schema::Authentication::Result::User;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );
use parent qw(App::MCP::Schema::Base);

use Class::Usul::Constants;

__PACKAGE__->table( 'user' );
__PACKAGE__->add_columns
   ( 'id',            { data_type         => 'integer',
                        default_value     => undef,
                        extra             => { unsigned => TRUE },
                        is_auto_increment => TRUE,
                        is_nullable       => FALSE, },
     'active',        { data_type         => 'boolean',
                        default_value     => 0,
                        is_nullable       => FALSE, },
     'username',      { data_type         => 'varchar',
                        default_value     => NUL,
                        is_nullable       => FALSE,
                        size              => 64, },
     'password',      { data_type         => 'varchar',
                        default_value     => NUL,
                        is_nullable       => FALSE,
                        size              => 64, },
     'email_address', { data_type         => 'varchar',
                        default_value     => NUL,
                        is_nullable       => FALSE,
                        size              => 64, },
     'first_name',    { data_type         => 'varchar',
                        default_value     => NUL,
                        is_nullable       => FALSE,
                        size              => 64, },
     'last_name',     { data_type         => 'varchar',
                        default_value     => NUL,
                        is_nullable       => FALSE,
                        size              => 64, },
     'home_phone',    { data_type         => 'varchar',
                        default_value     => NUL,
                        is_nullable       => FALSE,
                        size              => 64, },
     'location',      { data_type         => 'varchar',
                        default_value     => NUL,
                        is_nullable       => FALSE,
                        size              => 64, },
     'project',       { data_type         => 'varchar',
                        default_value     => NUL,
                        is_nullable       => FALSE,
                        size              => 64, },
     'work_phone',    { data_type         => 'varchar',
                        default_value     => NUL,
                        is_nullable       => FALSE,
                        size              => 64, },
     'pwlast',        { data_type         => 'mediumint',
                        default_value     => 0,
                        is_nullable       => FALSE, },
     'pwnext',        { data_type         => 'mediumint',
                        default_value     => 0,
                        is_nullable       => FALSE, },
     'pwafter',       { data_type         => 'mediumint',
                        default_value     => 99999,
                        is_nullable       => FALSE, },
     'pwwarn',        { data_type         => 'mediumint',
                        default_value     => 7,
                        is_nullable       => FALSE, },
     'pwexpires',     { data_type         => 'mediumint',
                        default_value     => 90,
                        is_nullable       => FALSE, },
     'pwdisable',     { data_type         => 'mediumint',
                        default_value     => undef,
                        is_nullable       => TRUE, }, );
__PACKAGE__->set_primary_key( 'id' );
__PACKAGE__->add_unique_constraint( [ 'username' ] );
__PACKAGE__->has_many(
   roles => 'App::MCP::Schema::Authentication::Result::UserRole', 'user_id' );

1;

__END__

=pod

=head1 Name

App::MCP::Schema::Authentication::Result::User - <One-line description of module's purpose>

=head1 Version

0.1.$Revision$

=head1 Synopsis

   use App::MCP::Schema::Authentication::Result::User;
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
