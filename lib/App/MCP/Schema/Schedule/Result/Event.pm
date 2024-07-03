package App::MCP::Schema::Schedule::Result::Event;

use strictures;
use parent 'App::MCP::Schema::Base';

use App::MCP::Constants qw( TRANSITION_ENUM );
use App::MCP::Util      qw( enumerated_data_type foreign_key_data_type
                            numerical_id_data_type serial_data_type
                            set_on_create_datetime_data_type
                            varchar_data_type );

my $class  = __PACKAGE__;
my $schema = 'App::MCP::Schema::Schedule';

$class->table('events');

$class->add_columns(
   id         => serial_data_type,
   created    => set_on_create_datetime_data_type,
   job_id     => foreign_key_data_type,
   transition => enumerated_data_type( TRANSITION_ENUM ),
   runid      => varchar_data_type( 20 ),
   pid        => numerical_id_data_type,
   rv         => numerical_id_data_type,
);

$class->set_primary_key('id');

$class->belongs_to('job' => "${schema}::Result::Job", 'job_id' );

sub insert {
   my $self = shift; $self->validate; return $self->next::method;
}

sub update {
   my ($self, $columns) = @_;

   $self->set_inflated_columns( %{ $columns } );
   $self->validate;

   return $self->next::method;
}

sub validation_attributes {
   return { # Keys: constraints, fields, and filters (all hashes)
      fields        => {
         job_id     => { validate => 'isMandatory isValidInteger' },
         pid        => { validate => 'isValidInteger' },
         transition => { validate => 'isMandatory isValidIdentifier' },
      },
   };
}

1;

__END__

=pod

=head1 Name

App::MCP::Schema::Schedule::Result::Event - <One-line description of module's purpose>

=head1 Synopsis

   use App::MCP::Schema::Schedule::Result::Event;
   # Brief but working code examples

=head1 Description

=head1 Configuration and Environment

=head1 Subroutines/Methods

=head2 insert

=head2 update

=head2 validation_attributes

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

Copyright (c) 2015 Peter Flanigan. All rights reserved

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
