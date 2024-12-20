package App::MCP::Schema::Schedule::ResultSet::JobCondition;

use strictures;
use parent 'DBIx::Class::ResultSet';

sub create_conditions {
   my ($self, $job) = @_;

   for my $job_id (split m{ / }mx, $job->dependencies // q()) {
      $self->create({ job_id => $job_id, reverse_id => $job->id });
   }

   return;
}

sub delete_conditions {
   my ($self, $job) = @_;

   $self->search({ reverse_id => $job->id })->delete;

   return;
}

1;

__END__

=pod

=head1 Name

App::MCP::Schema::Schedule::ResultSet::JobCondition - <One-line description of module's purpose>

=head1 Synopsis

   use App::MCP::Schema::Schedule::ResultSet::JobCondition;
   # Brief but working code examples

=head1 Description

=head1 Configuration and Environment

=head1 Subroutines/Methods

=head1 Diagnostics

=head1 Dependencies

=over 3

=item L<DBIx::Class>

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
