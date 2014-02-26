package App::MCP::Role::FormHandler;

use namespace::sweep;

use Class::Usul::Constants;
use HTML::FormWidgets;
use Scalar::Util qw( blessed );
use Moo::Role;

requires qw( serialize );

around 'serialize' => sub {
   my ($orig, $self, $req, $stash) = @_;

   if (exists $stash->{form} and blessed $stash->{form}) {
      my $widgets = HTML::FormWidgets->build( $stash->{form} );

      $stash->{page}->{literal_js} = $stash->{form}->{literal_js};
      $stash->{form} = $widgets;
   }

   return $orig->( $self, $req, $stash );
};

1;

__END__

=pod

=encoding utf8

=head1 Name

App::MCP::Role::FormHandler - One-line description of the modules purpose

=head1 Synopsis

   use App::MCP::Role::FormHandler;
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
