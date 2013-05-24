# @(#)$Ident: Schedule.pm 2013-04-30 23:35 pjf ;

package App::MCP::Schema::Schedule;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.2.%d', q$Rev: 1 $ =~ /\d+/gmx );
use parent q(DBIx::Class::Schema);

use File::Spec::Functions qw(catfile);
use Scalar::Util          qw(blessed);

__PACKAGE__->load_namespaces;

sub ddl_filename {
    my ($self, $type, $version, $dir, $preversion) = @_;

    ($dir, $version) = ($version, $dir) if ($DBIx::Class::VERSION < 0.08100);

    (my $filename = (blessed $self || $self)) =~ s{ :: }{-}gmx;
    $version = join q(.), (split m{ [.] }mx, $version)[ 0, 1 ];
    $preversion and $version = "${preversion}-${version}";
    return catfile( $dir, "${filename}-${version}-${type}.sql" );
}

1;

__END__

=pod

=head1 Name

App::MCP::Schema::Schedule - <One-line description of module's purpose>

=head1 Version

This documents version v0.2.$Rev: 1 $

=head1 Synopsis

   use App::MCP::Schema::Schedule;
   # Brief but working code examples

=head1 Description

=head1 Configuration and Environment

=head1 Subroutines/Methods

=head2 ddl_filename

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
