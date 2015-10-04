package App::MCP::Form::Field;

use namespace::autoclean;

use Class::Usul::Constants qw( NUL TRUE );
use Class::Usul::Functions qw( first_char );
use Class::Usul::Types     qw( HashRef );
use Moo;

has 'properties' => is => 'ro', isa => HashRef, required => TRUE;

my $_get_key = sub {
   my $self = shift; my $type = $self->properties->{type} // NUL;

   return $type eq 'button'  ? 'name'
        : $type eq 'chooser' ? 'href'
        : $type eq 'label'   ? 'text'
        : $type eq 'tree'    ? 'data'
                             : 'default';
};

around 'BUILDARGS' => sub {
   my ($orig, $self, $fields, $form_name, $name) = @_;

   my $fqfn  = first_char $name eq '+'
             ? substr $name, 1 : "${form_name}.${name}";
   my $props = { %{ $fields->{ $fqfn } // {} } };
   my $col   = $name; $col =~ s{ \A \+ }{}mx;

   exists $props->{name} or $props->{name} = $col;
   exists $props->{form} or exists $props->{group} or exists $props->{widget}
       or $props->{widget} = TRUE;

   return { properties => $props };
};

sub add_properties {
   my ($self, $value) = @_; my $props = $self->properties;

   $props->{ $_ } = $value->{ $_ } for (keys %{ $value });

   return;
}

sub key_value {
   my ($self, $v) = @_;

   defined $v and return $self->properties->{ $self->$_get_key } = $v;

   return $self->properties->{ $self->$_get_key };
}

sub name {
   return $_[ 0 ]->properties->{name};
}

1;

__END__

=pod

=encoding utf8

=head1 Name

App::MCP::Form::Field - One-line description of the modules purpose

=head1 Synopsis

   use App::MCP::Form::Field;
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
# vim: expandtab shiftwidth=3:
