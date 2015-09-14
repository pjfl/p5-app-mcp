package App::MCP::Exception;

use namespace::autoclean;

use Unexpected::Functions qw( has_exception );
use Moo;

extends 'Class::Usul::Exception';

my $class = __PACKAGE__;

has_exception $class              => parents => [ 'Class::Usul::Exception' ];

has_exception 'Authentication'    => parents => [ $class ];

has_exception 'Workflow'          => parents => [ $class ];

has_exception 'AccountInactive'   => parents => [ 'Authentication' ],
   error   => 'User [_1] authentication failed';

has_exception 'IncorrectPassword' => parents => [ 'Authentication' ],
   error   => 'User [_1] authentication failed';

has_exception 'Condition'         => parents => [ 'Workflow' ],
   error   => 'Condition not true';

has_exception 'Crontab'           => parents => [ 'Workflow' ],
   error   => 'Not at this time';

has_exception 'Illegal'           => parents => [ 'Workflow' ],
   error   => 'Transition [_1] from state [_2] illegal';

has_exception 'Retry'             => parents => [ 'Workflow' ],
   error   => 'Rv [_1] greater than expected [_2]';

has_exception 'Unknown'           => parents => [ 'Workflow' ];

has '+class' => default => $class;

sub code {
   return $_[ 0 ]->rv;
}

1;

__END__

=pod

=encoding utf8

=head1 Name

App::MCP::Exception - One-line description of the modules purpose

=head1 Synopsis

   use App::MCP::Exception;
   # Brief but working code examples

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

Copyright (c) 2015 Peter Flanigan. All rights reserved

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
