# @(#)Ident: Role.pm 2013-10-21 23:23 pjf ;

package App::MCP::Schema::Schedule::ResultSet::Role;

use strict;
use warnings;
use feature                 qw( state );
use version; our $VERSION = qv( sprintf '0.3.%d', q$Rev: 6 $ =~ /\d+/gmx );
use parent                  qw( DBIx::Class::ResultSet );

use Class::Usul::Constants;
use Class::Usul::Functions  qw( throw );

sub find_by_name {
   my ($self, $rolename) = @_;

   my $role = $self->search( { rolename => $rolename } )->single
      or throw error => 'Role [_1] unknown', args => [ $rolename ];

   return $role;
}

1;

__END__

=pod

=encoding utf8

=head1 Name

App::MCP::Schema::Schedule::ResultSet::Role - One-line description of the modules purpose

=head1 Synopsis

   use App::MCP::Schema::Schedule::ResultSet::Role;
   # Brief but working code examples

=head1 Version

This documents version v0.1.$Rev: 6 $ of L<App::MCP::Schema::Schedule::ResultSet::Role>

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
