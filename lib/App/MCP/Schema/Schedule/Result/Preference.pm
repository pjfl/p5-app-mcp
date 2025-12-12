package App::MCP::Schema::Schedule::Result::Preference;

use App::MCP::Constants qw( FALSE TRUE );
use App::MCP::Util      qw( foreign_key_data_type serial_data_type
                            text_data_type );
use JSON::MaybeXS       qw( decode_json encode_json );
use DBIx::Class::Moo::ResultClass;

my $class  = __PACKAGE__;
my $result = 'App::MCP::Schema::Schedule::Result';

$class->table('preferences');

$class->add_columns(
   id      => { %{serial_data_type()}, label => 'Preference ID' },
   user_id => {
      %{foreign_key_data_type()},
      display => 'user.user_name',
      label   => 'User',
   },
   name    => text_data_type(),
   value   => { %{text_data_type()}, is_nullable => TRUE },
);

$class->set_primary_key('id');

$class->add_unique_constraint(
   'preferences_user_id_name_uniq', ['user_id', 'name']
);

$class->belongs_to('user' => "${result}::User", 'user_id');

$class->inflate_column('value', {
   deflate => sub { encode_json(shift) },
   inflate => sub { decode_json(shift) },
});

sub preference {
   my ($self, $name, $value) = @_;

   $self->value->{$name} = $value if defined $value;

   return $self->value->{$name};
}

use namespace::autoclean;

1;

__END__

=pod

=encoding utf-8

=head1 Name

App::MCP::Schema::Schedule::Result::Preference - Master Control Program - Dependency and time based job scheduler

=head1 Synopsis

   use App::MCP::Schema::Schedule::Result::Preference;
   # Brief but working code examples

=head1 Description

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=back

=head1 Subroutines/Methods

=head1 Diagnostics

=head1 Dependencies

=over 3

=item L<Class::Usul>

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

Copyright (c) 2025 Peter Flanigan. All rights reserved

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
