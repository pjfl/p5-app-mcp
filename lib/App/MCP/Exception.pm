# @(#)Ident: Exception.pm 2013-11-23 21:05 pjf ;

package App::MCP::Exception;

use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.3.%d', q$Rev: 10 $ =~ /\d+/gmx );

use Moo;

extends q(Class::Usul::Exception);

my $class = __PACKAGE__;

$class->has_exception( $class             => [ 'Class::Usul::Exception' ] );
$class->has_exception( Authentication     => [ $class ] );
$class->has_exception( MissingDependency  => [ $class ] );
$class->has_exception( Workflow           => [ $class ] );
$class->has_exception( AccountInactive    => [ 'Authentication' ] );
$class->has_exception( ChecksumFailure    => [ 'Authentication' ] );
$class->has_exception( IncorrectPassword  => [ 'Authentication' ] );
$class->has_exception( MissingChecksum    => [ 'Authentication' ] );
$class->has_exception( MissingKey         => [ 'Authentication' ] );
$class->has_exception( SigParserFailure   => [ 'Authentication' ] );
$class->has_exception( SigVerifyFailure   => [ 'Authentication' ] );
$class->has_exception( Condition          => [ 'Workflow' ] );
$class->has_exception( Crontab            => [ 'Workflow' ] );
$class->has_exception( Illegal            => [ 'Workflow' ] );
$class->has_exception( Retry              => [ 'Workflow' ] );
$class->has_exception( Unknown            => [ 'Workflow' ] );

has '+class' => default => $class;

1;

__END__

=pod

=encoding utf8

=head1 Name

App::MCP::Exception - One-line description of the modules purpose

=head1 Synopsis

   use App::MCP::Exception;
   # Brief but working code examples

=head1 Version

This documents version v0.3.$Rev: 10 $ of L<App::MCP::Exception>

=head1 Description

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=back

=head1 Subroutines/Methods

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
