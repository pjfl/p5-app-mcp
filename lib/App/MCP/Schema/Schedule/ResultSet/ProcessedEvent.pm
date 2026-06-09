package App::MCP::Schema::Schedule::ResultSet::ProcessedEvent;

use Scalar::Util qw( blessed );
use Moo;

extends 'DBIx::Class::ResultSet';

sub find_last_start {
   my ($self, $job) = @_;

   my $columns  = ['created', 'runid', 'token'];
   my $order_by = { -desc => 'created' };
   my $options  = { columns => $columns, order_by => $order_by, rows => 1 };
   my $where    = { job_id => $job->id, transition => ['force_start', 'start']};

   return $self->search($where, $options)->single;
}

use namespace::autoclean;

1;

__END__

=pod

=encoding utf-8

=head1 Name

App::MCP::Schema::Schedule::ResultSet::ProcessedEvent - Master Control Program - Dependency and time based job scheduler


=head1 Synopsis

   use App::MCP::Schema::Schedule::ResultSet::ProcessedEvent;
   # Brief but working code examples

=head1 Description

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=cut

=back

=head1 Subroutines/Methods

Defineds the following methods;

=over 3

=cut

=back

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Moo>

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

Copyright (c) 2026 Peter Flanigan. All rights reserved

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
