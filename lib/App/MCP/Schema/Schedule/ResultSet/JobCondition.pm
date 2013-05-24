# @(#)$Ident: JobCondition.pm 2013-04-30 23:38 pjf ;

package App::MCP::Schema::Schedule::ResultSet::JobCondition;

use strict;
use version; our $VERSION = qv( sprintf '0.2.%d', q$Rev: 1 $ =~ /\d+/gmx );
use parent  qw(DBIx::Class::ResultSet);

use Class::Usul::Functions qw(throw);

sub create_dependents {
   my ($self, $job, $id) = @_; my $rs = $job->result_source->resultset;

   for my $fqjn (@{ $rs->eval_condition( $job )->[ 1 ] }) {
      my $jobs = $rs->search( { fqjn => $fqjn } );
      my $job  = $jobs->first or throw error => 'Job [_1] unknown',
                                       args  => [ $fqjn ];

      $self->create( { job_id => $job->id, reverse_id => $id } );
   }

   return;
}

sub delete_dependents {
   my ($self, $id) = @_; $self->search( { reverse_id => $id } )->delete; return;
}

1;

__END__

=pod

=head1 Name

App::MCP::Schema::Schedule::ResultSet::JobCondition - <One-line description of module's purpose>

=head1 Version

This documents version v0.2.$Rev: 1 $

=head1 Synopsis

   use App::MCP::Schema::Schedule::ResultSet::JobCondition;
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
