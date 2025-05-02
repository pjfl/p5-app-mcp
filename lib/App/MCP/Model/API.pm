package App::MCP::Model::API;

use App::MCP::Constants    qw( EXCEPTION_CLASS FALSE TRUE );
use Unexpected::Types      qw( HashRef Str );
use Class::Usul::Cmd::Util qw( ensure_class_loaded );
use Unexpected::Functions  qw( catch_class throw APIMethodFailed
                               UnauthorisedAPICall UnknownAPIClass
                               UnknownAPIMethod UnknownView );
use Try::Tiny;
use Moo;
use App::MCP::Attributes; # Will do namespace cleaning

extends 'App::MCP::Model';
with    'Web::Components::Role';

has '+moniker' => default => 'api';

has 'namespace' => is => 'ro', isa => Str, default => 'App::MCP::API';

has 'routes' =>
   is      => 'ro',
   isa     => HashRef,
   default => sub {
      return {
         'api/diagram_preference'  => 'api/diagram/*/preference',
         'api/form_validate_field' => 'api/form/*/field/*/validate',
         'api/navigation_messages' => 'api/navigation/collect/messages',
         'api/object_fetch'        => 'api/object/*/fetch',
         'api/object_get'          => 'api/object/*/get',
         'api/table_action'        => 'api/table/*/action',
         'api/table_preference'    => 'api/table/*/preference',
      };
   };

sub dispatch : Auth('none') {
   my ($self, $context, @args) = @_;

   throw UnknownView, ['json'] unless exists $context->views->{'json'};

   my ($ns, $name, $method) = splice @args, 0, 3;
   my $class = ('+' eq substr $ns, 0, 1)
      ? substr $ns, 1 : $self->namespace . '::' . ucfirst lc $ns;

   try   { ensure_class_loaded $class }
   catch { $self->error($context, UnknownAPIClass, [$class, $_]) };

   return if $context->stash->{finalised};

   my $args    = { config => $self->config, log => $self->log, name => $name };
   my $handler = $class->new($args);
   my $action  = $handler->can($method);

   return $self->error($context, UnknownAPIMethod, [$class, $method])
      unless $action;

   return $self->error($context, UnauthorisedAPICall, [$class, $method])
      unless $self->_api_call_allowed($context, $action);

   return if $context->posted && !$self->verify_form_post($context);

   try { $handler->$method($context, @args) }
   catch_class [
      'App::MCP::Exception' => sub { $self->error($context, $_) },
      '*' => sub { $self->error($context, APIMethodFailed, [$class,$method,$_])}
   ];

   $context->stash(json => (delete($context->stash->{response}) || {}))
      unless $context->stash('json');

   return if $context->stash->{finalised};

   $context->stash(view => 'json') unless $context->stash->{view};
   return;
}

sub _api_call_allowed {
   my ($self, $context, $action) = @_;

   return TRUE if $self->is_authorised($context, $action);

   $context->clear_redirect;
   return FALSE;
}

1;

__END__

=pod

=encoding utf8

=head1 Name

App::MCP::Model::API - One-line description of the modules purpose

=head1 Synopsis

   use App::MCP::Model::API;
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
# vim: expandtab shiftwidth=3:
