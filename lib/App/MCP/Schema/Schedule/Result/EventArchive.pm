# @(#)$Id$

package App::MCP::Schema::Schedule::Result::EventArchive;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );
use parent qw(App::MCP::Schema::Base);

use Class::Usul::Constants;

my $class = __PACKAGE__; my $schema = 'App::MCP::Schema::Schedule';

$class->table( 'event_archive' );

$class->add_columns
   ( id        => $class->serial_data_type,
     created   => { data_type => 'datetime' },
     job_id    => $class->foreign_key_data_type,
     pid       => $class->numerical_id_data_type,
     processed => $class->set_on_create_datetime_data_type,
     runid     => $class->varchar_data_type( 20 ),
     rv        => $class->numerical_id_data_type,
     state     => $class->enumerated_data_type( 'state_enum' ),
     token     => $class->varchar_data_type( 32 ),
     type      => $class->enumerated_data_type( 'event_type_enum' ), );

$class->set_primary_key( 'id' );

$class->belongs_to( job_rel => "${schema}::Result::Job", 'job_id' );

sub sqlt_deploy_hook {
  my ($self, $sqlt_table) = @_;

  $sqlt_table->add_index( name   => 'event_archive_runid',
                          fields => [ 'runid' ] );

  return;
}

1;

__END__

=pod

=head1 Name

App::MCP::Schema::Schedule::Result::EventArchive - <One-line description of module's purpose>

=head1 Version

0.1.$Revision$

=head1 Synopsis

   use App::MCP::Schema::Schedule::Result::EventArchive;
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
