# @(#)Ident: Base.pm 2013-05-29 19:05 pjf ;

package App::MCP::Async::Base;

use version; our $VERSION = qv( sprintf '0.2.%d', q$Rev: 10 $ =~ /\d+/gmx );

use Class::Usul::Moose;
use Class::Usul::Constants;

has 'autostart'   => is => 'ro',   isa => Bool, default => FALSE;

has 'builder'     => is => 'ro',   isa => Object, handles => [ qw(log) ],
   required       => TRUE;

has 'description' => is => 'ro',   isa => NonEmptySimpleStr, required => TRUE;

has 'log_key'     => is => 'ro',   isa => NonEmptySimpleStr, required => TRUE;

has 'loop'        => is => 'ro',   isa => Object, required => TRUE;

has 'pid'         => is => 'lazy', isa => PositiveInt;

__PACKAGE__->meta->make_immutable;

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

This documents version v0.2.$Rev: 10 $ of L<App::MCP::Async::Base>

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