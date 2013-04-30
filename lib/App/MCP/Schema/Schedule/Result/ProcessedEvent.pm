# @(#)$Ident: ;

package App::MCP::Schema::Schedule::Result::ProcessedEvent;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 1 $ =~ /\d+/gmx );
use parent qw(App::MCP::Schema::Base);

use Class::Usul::Constants;

my $class = __PACKAGE__; my $schema = 'App::MCP::Schema::Schedule';

$class->table( 'processed_event' );

$class->add_columns
   ( id         => $class->serial_data_type,
     created    => { data_type => 'datetime' },
     processed  => $class->set_on_create_datetime_data_type,
     job_id     => $class->foreign_key_data_type,
     transition => $class->enumerated_data_type( 'transition_enum' ),
     rejected   => $class->varchar_data_type( 16 ),
     runid      => $class->varchar_data_type( 20 ),
     token      => $class->varchar_data_type( 32 ),
     pid        => $class->numerical_id_data_type,
     rv         => $class->numerical_id_data_type, );

$class->set_primary_key( 'id' );

$class->belongs_to( job_rel => "${schema}::Result::Job", 'job_id' );

sub sqlt_deploy_hook {
  my ($self, $sqlt_table) = @_;

  $sqlt_table->add_index( name   => 'processed_event_idx_runid',
                          fields => [ 'runid' ] );

  return;
}

1;

__END__

=pod

=head1 Name

App::MCP::Schema::Schedule::Result::ProcessedEvent - <One-line description of module's purpose>

=head1 Version

0.1.$Revision: 1 $

=head1 Synopsis

   use App::MCP::Schema::Schedule::Result::ProcessedEvent;
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
