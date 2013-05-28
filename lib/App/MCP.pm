# @(#)$Ident: MCP.pm 2013-05-28 10:23 pjf ;

package App::MCP;

use 5.01;
use strict;
use version; our $VERSION = qv( sprintf '0.2.%d', q$Rev: 6 $ =~ /\d+/gmx );

1;

__END__

=pod

=head1 Name

App::MCP - Master Control Program - Dependency and time based job scheduler

=head1 Version

This documents version v0.2.$Rev: 6 $

=head1 Synopsis

   use App::MCP::Daemon;

   exit App::MCP::Daemon->new_with_options
      ( appclass => 'App::MCP', nodebug => 1 )->run;

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

