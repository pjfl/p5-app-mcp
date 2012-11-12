# @(#)$Id$

package App::MCP::Schema::Schedule::Result::Event;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );
use parent qw(App::MCP::Schema::Base);

use Class::Usul::Constants;

my $class = __PACKAGE__;
my $types = [ qw(status_update job_start) ];

$class->table( 'event' );
$class->add_columns
   ( id        => $class->serial_data_type,
     command   => { data_type         => 'varchar',
                    default_value     => undef,
                    is_nullable       => TRUE,
                    size              => 255, },
     created   => { data_type         => 'datetime',
                    set_on_create     => 1, },
     directory => { data_type         => 'varchar',
                    default_value     => undef,
                    is_nullable       => TRUE,
                    size              => 255, },
     happened  => { data_type         => 'datetime',
                    is_nullable       => TRUE, },
     host      => { data_type         => 'varchar',
                    default_value     => 'localhost',
                    is_nullable       => FALSE,
                    size              => 64, },
     pid       => { data_type         => 'smallint',
                    default_value     => undef,
                    is_nullable       => FALSE, },
     runid     => { data_type         => 'varchar',
                    default_value     => undef,
                    is_nullable       => FALSE,
                    size              => 20, },
     rv        => { data_type         => 'smallint',
                    default_value     => undef,
                    is_nullable       => FALSE, },
     status    => { data_type         => 'smallint',
                    default_value     => undef,
                    is_nullable       => FALSE, },
     type      => { data_type         => 'enum',
                    extra             => { list => $types },
                    is_enum           => TRUE, },
     user      => { data_type         => 'varchar',
                    default_value     => undef,
                    is_nullable       => TRUE,
                    size              => 32, }, );
$class->set_primary_key( 'id' );

1;

__END__

=pod

=head1 Name

App::MCP::Schema::Schedule::Result::Event - <One-line description of module's purpose>

=head1 Version

0.1.$Revision$

=head1 Synopsis

   use App::MCP::Schema::Schedule::Result::Event;
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
