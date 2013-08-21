# @(#)Ident: Base.pm 2013-06-24 12:17 pjf ;

package App::MCP::Async::Base;

use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.3.%d', q$Rev: 1 $ =~ /\d+/gmx );

use Class::Usul::Constants;
use Class::Usul::Types      qw( Bool NonEmptySimpleStr
                                Object NonZeroPositiveInt );
use Moo;

has 'autostart'   => is => 'ro',   isa => Bool, default => TRUE;

has 'builder'     => is => 'ro',   isa => Object,
   handles        => [ qw( config debug file log loop run_cmd ) ],
   required       => TRUE;

has 'description' => is => 'ro',   isa => NonEmptySimpleStr, required => TRUE;

has 'log_key'     => is => 'ro',   isa => NonEmptySimpleStr, required => TRUE;

has 'pid'         => is => 'lazy', isa => NonZeroPositiveInt;

1;

__END__

=pod

=encoding utf8

=head1 Name

App::MCP::Async::Base - One-line description of the modules purpose

=head1 Synopsis

   use App::MCP::Async::Base;
   # Brief but working code examples

=head1 Version

This documents version v0.3.$Rev: 1 $ of L<App::MCP::Async::Base>

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
