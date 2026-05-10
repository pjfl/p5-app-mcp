package App::MCP::Form::Role;

use HTML::Forms::Constants qw( FALSE META TRUE );
use HTML::Forms::Types     qw( ArrayRef Int Str );
use Class::Usul::Cmd::Util qw( includes );
use Data::Validate::IP     qw( is_ip );
use List::Util             qw( pairs );
use Moo;
use HTML::Forms::Moo;

extends 'HTML::Forms::Model::DBIC';
with    'HTML::Forms::Role::Defaults';

=pod

=encoding utf-8

=head1 Name

App::MCP::Form::Role - Role form

=head1 Synopsis

   use App::MCP::Form::Role;

=head1 Description

Role form

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=cut

has '+item_class' => default => 'Role';
has '+name'       => default => 'Role';
has '+title'      => default => 'Role';

has 'resultset' =>
   is      => 'lazy',
   default => sub {
      my $self = shift;

      return $self->context->model($self->item_class);
   };

has '_icons' =>
   is      => 'lazy',
   isa     => Str,
   default => sub { shift->context->icons_uri->as_string };

=back

=head1 Subroutines/Methods

Defineds the following methods;

=over 3

=cut

has_field 'role_name', required => TRUE, validate_inline => TRUE;

sub validate_role_name {
   my $self = shift;
   my $name = $self->field('role_name');

   $name->add_error("Role name '[_1]' too short", $name->value || '<empty>')
      if length $name->value < $self->context->config->user->{min_name_len};

   $name->add_error("Role name '[_1]' not unique", $name->value || '<empty>')
      if !$self->item_id && $self->resultset->find({role_name => $name->value});

   return;
}

has_field 'submit' => type => 'Button';

has_field 'view' =>
   type          => 'Link',
   label         => 'View',
   element_class => ['form-button'],
   wrapper_class => ['input-button', 'inline'];

after 'after_build_fields' => sub {
   my $self    = shift;
   my $context = $self->context;
   my $config  = $context->config;

   if ($self->item) {
      $self->field('submit')->add_wrapper_class(['inline', 'right']);

      my $view = $context->uri_for_action('role/view', [$self->item->id]);

      $self->field('view')->href($view->as_string);
   }
   else { $self->field('view')->inactive(TRUE) }

   my $role_name = $self->field('role_name');

   $role_name->element_attr->{minlength} = $config->user->{min_name_len};
   return;
};

use namespace::autoclean -except => META;

1;

__END__

=back

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Moo>

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

Copyright (c) 2026 Peter Flanigan. All rights reserved

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
