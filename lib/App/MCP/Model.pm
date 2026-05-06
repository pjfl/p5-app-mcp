package App::MCP::Model;

use App::MCP::Constants qw( FALSE NUL TRUE );
use App::MCP::Util      qw( formpost );
use Type::Utils         qw( class_type );
use HTML::Forms::Manager;
use HTML::StateTable::Manager;
use Web::Components::Navigation;
use Moo;
use App::MCP::Attributes; # Will do namespace cleaning

extends 'Web::Components::Model';
with    'App::MCP::Role::Authorisation';
with    'App::MCP::Role::Schema';

=pod

=encoding utf8

=head1 Name

App::MCP::Model - Model base class

=head1 Synopsis

   package App::MCP::Model::MyModel;

   use Moo;

   extends 'App::MCP::Model';

=head1 Description

Model base class

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=item C<form_factory>

An instance of the L<form factory|HTML::Forms::Manager> class

=cut

has 'form_factory' =>
   is      => 'lazy',
   isa     => class_type('HTML::Forms::Manager'),
   handles => { new_form => 'new_with_context' },
   default => sub {
      my $self     = shift;
      my $appclass = $self->config->appclass;

      return HTML::Forms::Manager->new({
         namespace      => "${appclass}::Form",
         renderer_class => 'HTML::Forms::Render::EmptyDiv',
         schema         => $self->schema
      });
   };

=item C<table_factory>

An instance of the L<table factory|HTML::StateTable::Manager> class

=cut

has 'table_factory' =>
   is      => 'lazy',
   isa     => class_type('HTML::StateTable::Manager'),
   handles => { new_table => 'new_with_context' },
   default => sub {
      my $self     = shift;
      my $appclass = $self->config->appclass;

      return HTML::StateTable::Manager->new({
         log       => $self->log,
         namespace => "${appclass}::Table",
         view_name => 'table',
      });
   };

=back

=head1 Subroutines/Methods

Defines the following methods;

=over 3

=item C<new_form>

   $form = $self->new_form('MyForm', { context => $context });

Creates new L<forms|HTML::Forms>

=item C<new_table>

   $table = $self->new_table('MyTable', { context => $context });

Creates new L<tables|HTML::StateTable>

=item C<root>

   $self->root($context);

Creates and stashes an instance of the
L<navigation|Web::Components::Navigation> object

Navigation methods C<menu>, C<list>, and C<item> are used to build the
context sensitive menu data

This method adds menu items for the C<Application> menu

=cut

sub root : Auth('none') {
   my ($self, $context) = @_;

   my $options = { context => $context, model => $self };
   my $nav     = Web::Components::Navigation->new($options);
   my $session = $context->session;

   if ($session->authenticated) {
      $nav->list('Documentation')->item('doc/application')->item('doc/server');

      $nav->list('_control');
      $nav->menu('Documentation', TRUE);
      $nav->item('misc/changes');
      $nav->item('misc/password', [$session->id]);
      $nav->item('user/profile', [$session->id]);
      $nav->item('user/totp', [$session->id]) if $session->enable_2fa;
      $nav->item(formpost, 'misc/logout');
   }
   else {
      $nav->list('_control');
      $nav->item('misc/login');
      $nav->item('misc/register', []) if $self->config->registration;
      $nav->item('misc/password', [$session->id]);
   }

   $context->stash($self->navigation_key => $nav);
   return;
}

1;

__END__

=back

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<App::MCP::Role::Authorisation>

=item L<App::MCP::Role::Schema>

=item L<Web::Components::Model>

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
