package App::MCP::Attributes;

use strictures;

use Sub::Install qw( install_sub );

my $Code_Attr = {};

=pod

=encoding utf-8

=head1 Name

App::MCP::Attributes - Subroutine attributes

=head1 Synopsis

   use App::MCP::Attributes;

=head1 Description

Subroutine attributes

=head1 Configuration and Environment

Defines no attributes

=cut

=head1 Subroutines/Methods

Defines the following methods;

=over 3

=item C<import>

=cut

sub import {
   my ($class, @wanted) = @_;

   my @export = (qw( FETCH_CODE_ATTRIBUTES MODIFY_CODE_ATTRIBUTES ));
   my $target = caller;

   namespace::autoclean->import( -cleanee => $target, -except => [@export] );

   return unless !defined $wanted[0] || $wanted[0];

   install_sub { as => $export[0], into => $target, code => \&fetch };
   install_sub { as => $export[1], into => $target, code => \&modify };
   return;
}

=item C<fetch>

=cut

sub fetch {
   my ($class, $code) = @_; return $Code_Attr->{ 0 + $code } // {};
}

=item C<modify>

=cut

sub modify {
   my ($class, $code, @attrs) = @_;

   for my $attr (@attrs) {
      my ($k, $v) = $attr =~ m{ \A ([^\(]+) (?: [\(] ([^\)]+) [\)] )? \z }mx;

      my $vals = $Code_Attr->{ 0 + $code }->{$k} //= [];

      next unless defined $v;

         $v =~ s{ \A \` (.*) \` \z }{$1}msx
      or $v =~ s{ \A \" (.*) \" \z }{$1}msx
      or $v =~ s{ \A \' (.*) \' \z }{$1}msx;

      push @{$vals}, $v;
      $Code_Attr->{ 0 + $code }->{$k} = $vals;
   }

   return ();
}

use namespace::autoclean ();

1;

__END__

=back

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Sub::Install>

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

Copyright (c) 2025 Peter Flanigan. All rights reserved

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
