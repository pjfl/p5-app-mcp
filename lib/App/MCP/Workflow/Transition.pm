# @(#)$Ident: Transition.pm 2013-06-24 12:06 pjf ;

package App::MCP::Workflow::Transition;

use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.2.%d', q$Rev: 20 $ =~ /\d+/gmx );

use Class::Usul::Constants;
use Moo;

extends q(Class::Workflow::Transition::Simple);

sub validate {
   my ($self, $instance, @args) = @_;

   for my $validator ($self->validators) {
      $self->$validator( $instance, @args );
   }

   return TRUE;
}

1;

__END__

=pod

=head1 Name

App::MCP::Workflow::Transition - <One-line description of module's purpose>

=head1 Version

This documents version v0.2.$Rev: 20 $

=head1 Synopsis

   use App::MCP::Workflow::Transition;
   # Brief but working code examples

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

Peter Flanigan, C<< <Support at RoxSoft dot co dot uk> >>

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
