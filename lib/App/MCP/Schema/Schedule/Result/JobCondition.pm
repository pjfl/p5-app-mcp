package App::MCP::Schema::Schedule::Result::JobCondition;

use strict;
use warnings;
use parent 'App::MCP::Schema::Base';

use App::MCP::Constants;

my $class = __PACKAGE__; my $schema = 'App::MCP::Schema::Schedule';

$class->table( 'job_condition' );

$class->add_columns( job_id     => $class->foreign_key_data_type,
                     reverse_id => $class->foreign_key_data_type, );

$class->set_primary_key( qw(job_id reverse_id) );

$class->belongs_to( job_rel => "${schema}::Result::Job", 'job_id' );

sub sqlt_deploy_hook {
  my ($self, $sqlt_table) = @_;

  $sqlt_table->add_index( name   => 'job_condition_idx_reverse_id',
                          fields => [ 'reverse_id' ] );

  return;
}

1;

__END__

=pod

=head1 Name

App::MCP::Schema::Schedule::Result::JobCondition - <One-line description of module's purpose>

=head1 Synopsis

   use App::MCP::Schema::Schedule::Result::JobCondition;
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
