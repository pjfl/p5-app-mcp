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

has 'form_manager' =>
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

has 'table_manager' =>
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

# Public methods
sub root : Auth('none') {
   my ($self, $context) = @_;

   my $session = $context->session;
   my $nav     = Web::Components::Navigation->new({
      context       => $context,
      footer_action => 'misc/footer',
      model         => $self,
   });

   $nav->list('_control');

   if ($session->authenticated) {
      $nav->item('misc/changes');
      $nav->item('misc/password', [$session->id]);
      $nav->item('user/profile', [$session->id]);
      $nav->item('user/totp', [$session->id]) if $session->enable_2fa;
      $nav->item(formpost, 'misc/logout');
   }
   else {
      $nav->item('misc/login');
      $nav->item('misc/password', [$session->id]);
      $nav->item('misc/register', []) if $self->config->registration;
   }

   $context->stash($self->navigation_key => $nav);
   return;
}

1;

__END__

=pod

=encoding utf8

=head1 Name

App::MCP::Model - One-line description of the modules purpose

=head1 Synopsis

   use App::MCP::Model;
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

=item L<Web::Components>

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
