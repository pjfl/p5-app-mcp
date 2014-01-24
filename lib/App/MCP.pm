# @(#)$Ident: MCP.pm 2014-01-24 15:13 pjf ;

package App::MCP;

use 5.010001;
use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.4.%d', q$Rev: 5 $ =~ /\d+/gmx );

use Moo;
use App::MCP::Constants;
use Class::Usul::Types      qw( BaseType );

has '_usul' => is => 'ro', isa => BaseType,
   handles  => [ qw( config debug localize log ) ],
   init_arg => 'builder', required => TRUE, weak_ref => TRUE;

1;

__END__

=pod

=head1 Name

App::MCP - Master Control Program - Dependency and time based job scheduler

=head1 Version

This documents version v0.4.$Rev: 5 $ of L<App::MCP>

=head1 Synopsis

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
