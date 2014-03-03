package App::MCP::Schema::Base;

use strictures;
use parent 'DBIx::Class::Core';

use App::MCP::Constants;
use Data::Validation;

__PACKAGE__->load_components( qw( InflateColumn::Object::Enum TimeStamp ) );

Data::Validation::Constants->Exception_Class( EXCEPTION_CLASS );

sub varchar_max_size {
   return 255;
}

sub job_type_enum {
   return [ qw( box job ) ];
}

sub state_enum {
   return [ qw( active hold failed finished
                inactive running starting terminated ) ];
}

sub transition_enum {
   return [ qw( activate fail finish off_hold
                on_hold start started terminate ) ];
}


sub enumerated_data_type {
   my ($self, $enum, $default) = @_;

   return { data_type         => 'enum',
            default_value     => $default,
            extra             => { list => $self->$enum() },
            is_enum           => TRUE, };
}

sub foreign_key_data_type {
   my ($self, $default, $accessor) = @_;

   my $type_info = { data_type     => 'integer',
                     default_value => $default,
                     extra         => { unsigned => TRUE },
                     is_nullable   => FALSE, };

   defined $accessor and $type_info->{accessor} = $accessor;

   return $type_info;
}

sub nullable_foreign_key_data_type {
   return { data_type         => 'integer',
            default_value     => undef,
            extra             => { unsigned => TRUE },
            is_nullable       => TRUE, };
}

sub nullable_varchar_data_type {
   return { data_type         => 'varchar',
            default_value     => $_[ 2 ],
            is_nullable       => TRUE,
            size              => $_[ 1 ] || $_[ 0 ]->varchar_max_size, };
}

sub numerical_id_data_type {
   return { data_type         => 'smallint',
            default_value     => $_[ 1 ],
            is_nullable       => FALSE, };
}

sub serial_data_type {
   return { data_type         => 'integer',
            default_value     => undef,
            extra             => { unsigned => TRUE },
            is_auto_increment => TRUE,
            is_nullable       => FALSE, };
}

sub set_on_create_datetime_data_type {
   return { data_type         => 'datetime',
            set_on_create     => TRUE, };
}

sub validation_attributes {
   return {};
}

sub varchar_data_type {
   return { data_type         => 'varchar',
            default_value     => $_[ 2 ],
            is_nullable       => FALSE,
            size              => $_[ 1 ] || $_[ 0 ]->varchar_max_size, };
}

# Private methods
sub _validate {
   my $self = shift; my $attr = $self->validation_attributes;

   defined $attr->{fields} or return;

   my $columns = { $self->get_inflated_columns };

   for my $field (keys %{ $attr->{fields} }) {
      my $valids =  $attr->{fields}->{ $field }->{validate} or next;
         $valids =~ m{ isMandatory }msx and $columns->{ $field } //= undef;
   }

   $columns = Data::Validation->new( $attr )->check_form( NUL, $columns );
   $self->set_inflated_columns( $columns );
   return;
}

1;

__END__

=pod

=head1 Name

App::MCP::Schema::Base - <One-line description of module's purpose>

=head1 Synopsis

   use App::MCP::Schema::Base;
   # Brief but working code examples

=head1 Description

=head1 Configuration and Environment

=head1 Subroutines/Methods

=head2 event_type_enum

=head2 job_type_enum

=head2 nullable_varchar_data_type

=head2 numerical_id_data_type

=head2 serial_data_type

=head2 state_enum

=head2 validation_attributes

=head2 varchar_data_type

=head2 varchar_max_size

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
