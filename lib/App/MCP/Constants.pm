# @(#)Ident: Constants.pm 2013-11-20 16:14 pjf ;

package App::MCP::Constants;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.3.%d', q$Rev: 10 $ =~ /\d+/gmx );
use parent                  qw( Exporter::Tiny );

use App::MCP::Exception;
use Class::Usul::Constants ();

Class::Usul::Constants->Exception_Class( 'App::MCP::Exception' );

our @EXPORT = qw( SEPARATOR );

sub import {
   my $class       = shift;
   my $global_opts = { $_[ 0 ] && ref $_[ 0 ] eq 'HASH' ? %{+ shift } : () };

   $global_opts->{into} ||= caller;
   Class::Usul::Constants->import( $global_opts );
   $class->SUPER::import( $global_opts );
   return;
}

sub SEPARATOR () { '/' }

1;

__END__

=pod

=encoding utf8

=head1 Name

App::MCP::Constants - One-line description of the modules purpose

=head1 Synopsis

   use App::MCP::Constants;
   # Brief but working code examples

=head1 Version

This documents version v0.3.$Rev: 10 $ of L<App::MCP::Constants>

=head1 Description

=head1 Configuration and Environment

Defines no attributes

=head1 Subroutines/Methods

=head2 SEPARATOR

The forward slash character. Used by L<App::MCP::MaterialisedPath>

=head1 Diagnostics

=head1 Dependencies

=over 3

=item L<Class::Usul>

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