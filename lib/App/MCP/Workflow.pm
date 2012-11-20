# @(#)$Id$

package App::MCP::Workflow;

use strict;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use Class::Usul::Moose;

extends qw(Class::Workflow);

sub BUILD {
   my $self = shift;

   $self->initial_state( 'inactive' );
   $self->state( name => 'active',     transitions => [ qw(on_hold start) ] );
   $self->state( name => 'hold',       transitions => [ qw(off_hold) ] );
   $self->state( name => 'failed',     transitions => [ qw(activate) ] );
   $self->state( name => 'finished',   transitions => [ qw(activate) ] );
   $self->state( name => 'inactive',   transitions => [ qw(activate) ] );
   $self->state( name => 'running',
                 transitions => [ qw(fail finish terminate) ] );
   $self->state( name => 'starting',   transitions => [ qw(started)  ] );
   $self->state( name => 'terminated', transitions => [ qw(activate) ] );

   $self->transition( name => 'activate',  to_state => 'active'     );
   $self->transition( name => 'fail',      to_state => 'failed'     );
   $self->transition( name => 'finish',    to_state => 'finished'   );
   $self->transition( name => 'off_hold',  to_state => 'active'     );
   $self->transition( name => 'on_hold',   to_state => 'hold'       );
   $self->transition( name => 'start',     to_state => 'starting'   );
   $self->transition( name => 'started',   to_state => 'running'    );
   $self->transition( name => 'terminate', to_state => 'terminated' );
   return;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=head1 Name

App::MCP::Workflow - <One-line description of module's purpose>

=head1 Version

0.1.$Revision$

=head1 Synopsis

   use App::MCP::Workflow;
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
