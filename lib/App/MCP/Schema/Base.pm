package App::MCP::Schema::Base;

use strictures;
use parent 'DBIx::Class::Core';

use App::MCP::Constants qw( NUL );
use Data::Validation;

my $class = __PACKAGE__;

$class->load_components( qw( InflateColumn::Object::Enum TimeStamp ) );

sub validate {
   my $self = shift;
   my $attr = $self->validation_attributes;

   return unless defined $attr->{fields};

   my $columns = { $self->get_inflated_columns };

   for my $field (keys %{$attr->{fields}}) {
      my $valids =  $attr->{fields}->{$field}->{validate} or next;

      $columns->{$field} //= undef if $valids =~ m{ isMandatory }msx;
   }

   $columns = Data::Validation->new($attr)->check_form(NUL, $columns);
   $self->set_inflated_columns($columns);
   return;
}

sub validation_attributes {
   return {};
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

=head2 validate

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
