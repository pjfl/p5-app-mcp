package App::MCP::Schema::Schedule::Result::JobState;

use strict;
use warnings;
use parent 'App::MCP::Schema::Base';

use App::MCP::Constants;

my $class = __PACKAGE__; my $schema = 'App::MCP::Schema::Schedule';

$class->table( 'job_state' );

$class->add_columns
   ( job_id    => $class->foreign_key_data_type,
     updated   => { data_type => 'datetime', },
     name      => $class->enumerated_data_type( 'state_enum' ), );

$class->set_primary_key( 'job_id' );

$class->belongs_to( job_rel   => "${schema}::Result::Job",   'job_id' );

$class->has_many  ( event_rel => "${schema}::Result::Event", 'job_id' );

1;

__END__

=pod

=head1 Name

App::MCP::Schema::Schedule::Result::JobStatus - <One-line description of module's purpose>

=head1 Synopsis

   use App::MCP::Schema::Schedule::Result::JobStatus;
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
