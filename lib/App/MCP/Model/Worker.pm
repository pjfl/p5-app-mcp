package App::MCP::Model::Worker;

use App::MCP::Constants    qw( EXCEPTION_CLASS FALSE NUL TRUE );
use HTTP::Status           qw( HTTP_BAD_REQUEST HTTP_CREATED HTTP_NOT_FOUND
                               HTTP_UNAUTHORIZED );
use App::MCP::Util         qw( trigger_event_handler );
use Class::Usul::Cmd::Util qw( decrypt trim );
use HTML::Forms::Util      qw( rwx2int );
use Unexpected::Functions  qw( throw );
use Try::Tiny;
use Moo;
use App::MCP::Attributes; # Will do namespace cleaning

extends 'App::MCP::Model';
with    'Web::Components::Role';
with    'App::MCP::Role::Redis';
with    'App::MCP::Role::JSONParser';
with    'App::MCP::Role::APIAuthentication';

has '+moniker' => default => 'worker';

sub runid : Auth('none') Capture(1) {
   my ($self, $context, $arg) = @_;

   my $token  = $self->redis_client->get("event_token-${arg}");
   my $result = [HTTP_NOT_FOUND, { message => "Runid ${arg} token not found" }];

   $self->stash_response($context, $result) unless $token;
   $context->stash(runid => $arg, token => $token) if $token;

   return;
}

sub sessionid : Auth('none') Capture(1) {
   my ($self, $context, $arg) = @_;

   my ($session, $result);

   try   { $session = $self->get_session($arg) }
   catch { $result = [HTTP_NOT_FOUND, { message => "${_}" } ] };

   $self->stash_response($context, $result) if $result;
   $context->stash(session => $session) if $session;

   return;
}

sub user : Auth('none') Capture(1) {
   my ($self, $context, $arg) = @_;

   my $user   = $context->find_user({ username => $arg });
   my $result = [HTTP_BAD_REQUEST, { message => "User ${arg} unknown" }];

   $self->stash_response($context, $result) unless $user;
   $context->stash(user => $user) if $user;

   return;
}

sub create_event : Auth('none') {
   my ($self, $context) = @_;

   return unless $self->authenticate_headers($context);

   my $runid     = $context->stash('runid');
   my $token     = $context->stash('token');
   my $encrypted = $context->body_parameters->{event};
   my $params    = $self->_decode_encrypted($context, $token, $encrypted);
   my $message   = "Runid ${runid} authentication failed";
   my $result    = [HTTP_UNAUTHORIZED, { message => $message }];

   return $self->stash_response($context, $result) unless $params;

   try {
      my $eventid = $self->schema->resultset('Event')->create($params)->id;

      $result = [HTTP_CREATED, { message => "Event ${eventid} created" }];
      trigger_event_handler $self->config;
   }
   catch {
      $result = [HTTP_BAD_REQUEST, { message => $self->_error_message($_) }];
   };

   $self->stash_response($context, $result);
   return;
}

sub create_job : Auth('none') {
   my ($self, $context) = @_;

   return unless $self->authenticate_headers($context);

   my $session    = $context->stash('session');
   my $session_id = $session->{id};
   my $secret     = $session->{shared_secret};
   my $encrypted  = $context->body_parameters->{job};
   my $params     = $self->_decode_encrypted($context, $secret, $encrypted);
   my $message    = "Session ${session_id} authentication failed";
   my $result     = [HTTP_UNAUTHORIZED, { message => $message }];

   return $self->stash_response($context, $result) unless $params;

   $self->_set_job_defaults($context, $params);

   try {
      my $jobid = $self->schema->resultset('Job')->create($params)->id;

      $result = [HTTP_CREATED, { message => "Job ${jobid} created" }];
   }
   catch {
      $result = [HTTP_BAD_REQUEST, { message => $self->_error_message($_) }];
   };

   $self->stash_response($context, $result);
   return;
}

# Private methods
sub _decode_encrypted {
   my ($self, $context, $secret, $encrypted) = @_;

   my $params;

   try   { $params = $self->json_parser->decode(decrypt $secret, $encrypted) }
   catch { $self->log->error($_, $context) };

   return $params;
}

sub _error_message {
   my ($self, $e) = @_;

   my $message = NUL;

   if ($e->can('class') and $e->class eq 'ValidationErrors') {
      $message .= ($message ? ' - ' : NUL) . trim "${_}" for (@{$e->args});
   }
   else {
      $message = trim "${e}";
      $message = 'Duplicate key'
         if $message =~ m{ duplicate \s+ key \s+ value }mx;
      $message = "No such column ${1}"
         if $message =~ m{ No \s+ such \s+ column \s+ ([\'][a-z_]+[\']) }mx;
   }

   return $message;
}

sub _set_job_defaults {
   my ($self, $context, $params) = @_;

   my $session = $context->stash('session');

   $context->session->username($session->{key});

   if (!$params->{group} || $params->{group} !~ m{ \A \d+ \z }mx) {
      my $group_name = delete $params->{group} // $self->config->prefix;
      my $group_rs   = $self->schema->resultset('Role');
      my $group      = $group_rs->find_by_key($group_name);

      $params->{group_id} = $group->id if $group;
   }

   $params->{owner_id} = $session->{user_id};

   $params->{parent_name} = delete $params->{parent} if $params->{parent};

   if ($params->{permissions} && $params->{permissions} !~ m{ \A \d+ \z }mx) {
      $params->{permissions} = rwx2int $params->{permissions};
   }

   $params->{user_name} = $self->config->prefix unless $params->{user_name};

   return;
}

1;

__END__

=pod

=encoding utf-8

=head1 Name

App::MCP::Model::Worker - Master Control Program - Dependency and time based job scheduler


=head1 Synopsis

   use App::MCP::Model::Worker;
   # Brief but working code examples

=head1 Description

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=cut

=back

=head1 Subroutines/Methods

Defineds the following methods;

=over 3

=cut

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
