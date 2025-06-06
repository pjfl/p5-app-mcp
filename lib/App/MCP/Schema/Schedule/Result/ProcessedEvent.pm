package App::MCP::Schema::Schedule::Result::ProcessedEvent;

use strictures;
use parent 'App::MCP::Schema::Base';

use App::MCP::Constants qw( TRANSITION_ENUM NUL );
use App::MCP::Util      qw( enumerated_data_type foreign_key_data_type
                            nullable_varchar_data_type numerical_data_type
                            numerical_id_data_type serial_data_type
                            set_on_create_datetime_data_type
                            varchar_data_type );

my $class  = __PACKAGE__;
my $result = 'App::MCP::Schema::Schedule::Result';

$class->table('processed_events');

$class->add_columns(
   id         => serial_data_type,
   created    => { data_type => 'datetime', timezone => 'UTC' },
   processed  => { %{set_on_create_datetime_data_type()}, timezone => 'UTC' },
   job_id     => foreign_key_data_type,
   transition => enumerated_data_type(TRANSITION_ENUM),
   rejected   => nullable_varchar_data_type(16),
   runid      => varchar_data_type(20),
   token      => varchar_data_type(32, NUL),
   pid        => numerical_data_type,
   rv         => numerical_id_data_type,
);

$class->set_primary_key('id');

$class->belongs_to(job => "${result}::Job", 'job_id');

sub sqlt_deploy_hook {
  my ($self, $sqlt_table) = @_;

  $sqlt_table->add_index(
     name   => 'processed_events_runid_idx',
     fields => ['runid'],
  );

  return;
}

1;

__END__

=pod

=head1 Name

App::MCP::Schema::Schedule::Result::ProcessedEvent - <One-line description of module's purpose>

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

Peter Flanigan, C<< <pjfl@cpan.org> >>

=head1 License and Copyright

Copyright (c) 2024 Peter Flanigan. All rights reserved

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
