# @(#)$Id$

package App::MCP::Schema::Schedule::ResultSet::JobState;

use strict;
use feature qw(state);
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );
use parent  qw(DBIx::Class::ResultSet);

use Class::Usul::Constants;
use Class::Usul::Functions qw(throw);

sub finished {
   my ($self, $fqjn) = @_; my $state = $self->_get_job_state( $fqjn );

   return $state eq 'finished' ? TRUE : FALSE ;
}

sub predicates {
   return [ qw(finished running terminated) ];
}

sub running {
   my ($self, $fqjn) = @_; my $state = $self->_get_job_state( $fqjn );

   return $state eq 'running' ? TRUE : FALSE
}

sub terminated {
   my ($self, $fqjn) = @_; my $state = $self->_get_job_state( $fqjn );

   return $state eq 'terminated' ? TRUE : FALSE;
}

# Private methods

sub _get_job_state {
   my ($self, $fqjn) = @_;

   state $job_rs //= $self->result_source->schema->resultset( 'Job' );

   my $jobs   = $job_rs->search( { fqjn => $fqjn } );
   my $job    = $jobs->first or throw error => 'Job [_1] unknown',
                                      args  => [ $fqjn ];
   my $state  = $self->find( $job->id );

   return $state ? $state->name : 'inactive';
}

1;

__END__

=pod

=head1 Name

App::MCP::Schema::Schedule::ResultSet::JobState - <One-line description of module's purpose>

=head1 Version

0.1.$Revision$

=head1 Synopsis

   use App::MCP::Schema::Schedule::ResultSet::JobState;
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
