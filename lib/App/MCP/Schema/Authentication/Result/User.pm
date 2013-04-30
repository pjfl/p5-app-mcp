# @(#)$Ident: ;

package App::MCP::Schema::Authentication::Result::User;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 1 $ =~ /\d+/gmx );
use parent qw(App::MCP::Schema::Base);

use Class::Usul::Constants;

my $class  = __PACKAGE__;
my $schema = 'App::MCP::Schema::Authentication';

$class->table( 'user' );

$class->add_columns
   ( id            => $class->serial_data_type,
     active        => { data_type     => 'boolean',
                        default_value => 0,
                        is_nullable   => FALSE, },
     username      => $class->varchar_data_type( 64, NUL ),
     password      => $class->varchar_data_type( 64, NUL ),
     email_address => $class->varchar_data_type( 64, NUL ),
     first_name    => $class->varchar_data_type( 64, NUL ),
     last_name     => $class->varchar_data_type( 64, NUL ),
     home_phone    => $class->varchar_data_type( 64, NUL ),
     location      => $class->varchar_data_type( 64, NUL ),
     project       => $class->varchar_data_type( 64, NUL ),
     work_phone    => $class->varchar_data_type( 64, NUL ),
     pwlast        => { data_type     => 'mediumint',
                        default_value => 0,
                        is_nullable   => FALSE, },
     pwnext        => { data_type     => 'mediumint',
                        default_value => 0,
                        is_nullable   => FALSE, },
     pwafter       => { data_type     => 'mediumint',
                        default_value => 99999,
                        is_nullable   => FALSE, },
     pwwarn        => { data_type     => 'mediumint',
                        default_value => 7,
                        is_nullable   => FALSE, },
     pwexpires     => { data_type     => 'mediumint',
                        default_value => 90,
                        is_nullable   => FALSE, },
     pwdisable     => { data_type     => 'mediumint',
                        default_value => undef,
                        is_nullable   => TRUE, }, );

$class->set_primary_key( 'id' );

$class->add_unique_constraint( [ 'username' ] );

$class->has_many( roles => "${schema}::Result::UserRole", 'user_id' );

1;

__END__

=pod

=head1 Name

App::MCP::Schema::Authentication::Result::User - <One-line description of module's purpose>

=head1 Version

0.1.$Revision: 1 $

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
