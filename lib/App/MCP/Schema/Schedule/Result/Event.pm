# @(#)$Id$

package App::MCP::Schema::Schedule::Result::Event;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );
use parent qw(App::MCP::Schema::Base);

use Class::Usul::Constants;

__PACKAGE__->table( 'event' );
__PACKAGE__->add_columns
   ( id        => { data_type         => 'integer',
                    default_value     => undef,
                    extra             => { unsigned => TRUE },
                    is_auto_increment => TRUE,
                    is_nullable       => FALSE, },
     pid       => { data_type         => 'smallint',
                    default_value     => undef,
                    is_nullable       => FALSE, },
     runid     => { data_type         => 'varchar',
                    default_value     => undef,
                    is_nullable       => FALSE,
                    size              => 20, },
     status    => { data_type         => 'smallint',
                    default_value     => undef,
                    is_nullable       => FALSE, },
     t_created => { data_type         => 'datetime',
                    set_on_create     => 1, },
     desc      => { data_type         => 'varchar',
                    default_value     => NUL,
                    is_nullable       => FALSE,
                    size              => 255, }, );
__PACKAGE__->set_primary_key( 'id' );
__PACKAGE__->add_unique_constraint( [ 'desc' ] );

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
