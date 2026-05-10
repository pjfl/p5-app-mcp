package App::MCP::Model::Role;

use App::MCP::Constants   qw( EXCEPTION_CLASS FALSE NUL TRUE );
use App::MCP::Util        qw( redirect redirect2referer );
use Unexpected::Functions qw( UnknownRole );
use Moo;
use App::MCP::Attributes; # Will do cleaning

extends 'App::MCP::Model';
with    'Web::Components::Role';

=pod

=encoding utf-8

=head1 Name

App::MCP::Model::Role - User roles

=head1 Synopsis

   use App::MCP::Model::Role;

=head1 Description

User roles

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=item C<moniker>

Defaults to C<role>

=cut

has '+moniker' => default => 'role';

=back

=head1 Subroutines/Methods

Defineds the following methods;

=over 3

=item C<base>

=cut

sub base : Auth('admin') {
   my ($self, $context) = @_;

   $context->stash('nav')->list('role')->item('role/create')->finalise;
   return;
}

=item C<role>

=cut

sub role : Auth('admin') Capture(1) {
   my ($self, $context, $arg) = @_;

   my $role = $context->model('Role')->find_by_key($arg);

   return $self->error($context, UnknownRole, [$arg]) unless $role;

   $context->stash(role => $role);

   my $nav = $context->stash('nav')->list('role')->item('role/create');

   $nav->crud('role', $role->id)->finalise;
   return;
}

=item C<create>

=cut

sub create : Auth('admin') Nav('Create Role') {
   my ($self, $context) = @_;

   my $options = { context => $context, title => 'Create Role' };
   my $form    = $self->new_form('Role', $options);

   if ($form->process(posted => $context->posted)) {
      my $view    = $context->uri_for_action('role/view', [$form->item->id]);
      my $message = 'Role [_1] created';

      $context->stash(redirect $view, [$message, $form->item->role_name]);
   }

   $context->stash(form => $form);
   return;
}

=item C<delete>

=cut

sub delete : Auth('admin') Nav('Delete Role') {
   my ($self, $context) = @_;

   return unless $self->verify_form_post($context);

   my $role = $context->stash->{role};
   my $name = $role->role_name;

   $role->delete;

   my $list = $context->uri_for_action('role/list');

   $context->stash(redirect $list, ['Role [_1] deleted', $name]);
   return;
}

=item C<edit>

=cut

sub edit : Auth('admin') Nav('Edit Role') {
   my ($self, $context) = @_;

   my $role    = $context->stash->{role};
   my $options = { context => $context, item => $role, title => 'Edit Role' };
   my $form    = $self->new_form('Role', $options);

   if ($form->process(posted => $context->posted)) {
      my $edit    = $context->uri_for_action('role/edit', [$role->id]);
      my $message = 'Role [_1] updated';

      $context->stash(redirect $edit, [$message, $form->item->role_name]);
   }

   $context->stash(form => $form);
   return;
}

=item C<remove>

=cut

sub remove : Auth('admin') {
   my ($self, $context) = @_;

   return unless $self->verify_form_post($context);

   my $value = $context->body_parameters->{data} or return;
   my $rs    = $context->model('Role');
   my $count = 0;

   for my $role (grep { $_ } map { $rs->find($_) } @{$value->{selector}}) {
      $role->delete;
      $count++;
   }

   $context->stash(redirect2referer $context, ["${count} roles(s) deleted"]);
   return;
}

=item C<list>

=cut

sub list : Auth('admin') Nav('Roles') {
   my ($self, $context) = @_;

   my $options = { context => $context, resultset => $context->model('Role') };

   $context->stash(table => $self->new_table('Role', $options));
   return;
}

=item C<view>

=cut

sub view : Auth('admin') Nav('View Role') {
   my ($self, $context) = @_;

   my $role    = $context->stash('role');
   my $options = {
      caption      => 'View Role',
      context      => $context,
      result       => $role,
      form_buttons => [{
         action    => $context->uri_for_action('role/list'),
         classes   => 'left',
         method    => 'get',
         selection => 'disable_on_select',
         value     => 'Roles',
      },{
         action    => $context->uri_for_action('role/edit', [$role->id]),
         method    => 'get',
         selection => 'disable_on_select',
         value     => 'Edit',
      }],
   };

   $context->stash(table => $self->new_table('View::Object', $options));
   return;
}

use namespace::autoclean;

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
