package strictures::defanged;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 13 $ =~ /\d+/gmx );

require strictures;

no warnings 'redefine';

*strictures::import = sub { strict->import; warnings->import };

1;

__END__

=pod

=encoding utf8

=head1 Name

strictures::defanged - Make strictures the same as just use strict warnings

=head1 Synopsis

   require strictures::defanged;

=head1 Version

This documents version v0.1.$Rev: 13 $ of L<strictures::defanged>

=head1 Description

Monkey patch the L<strictures> import method. Make it the same as just

   use strict;
   use warnings;

=head1 Configuration and Environment

Defines no attributes

=head1 Subroutines/Methods

None

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<strictures>

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

Copyright (c) 2014 Peter Flanigan. All rights reserved

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
