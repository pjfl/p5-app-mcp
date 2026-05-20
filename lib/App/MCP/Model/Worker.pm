package App::MCP::Model::Worker;

use App::MCP::Constants    qw( EXCEPTION_CLASS FALSE TRUE );
use HTTP::Status           qw( HTTP_BAD_REQUEST HTTP_CREATED HTTP_NOT_FOUND
                               HTTP_OK HTTP_UNAUTHORIZED is_error );
use App::MCP::Util         qw( trigger_input_handler );
use Class::Usul::Cmd::Util qw( decrypt );
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

   $context->stash(runid => $arg);
   return;
}

sub sessionid : Auth('none') Capture(1) {
   my ($self, $context, $arg) = @_;

   $context->stash(sessionid => $arg);
   return;
}

sub user : Auth('none') Capture(1) {
   my ($self, $context, $arg) = @_;

   $context->stash(username => $arg);
   return;
}

sub create_event : Auth('none') {
   my ($self, $context) = @_;

   my $request = $context->request;
   my $result;

   try   { $request->authenticate_headers }
   catch { $result = [HTTP_BAD_REQUEST, { message => "${_}" }] };

   return $self->_stash_response($context, $result) if $result;

   my $runid  = $context->stash('runid');
   my $secret = $self->redis_client->get("event_token-${runid}");

   $result = [HTTP_NOT_FOUND, { message => "Runid ${runid} token not found" }];

   return $self->_stash_response($context, $result) unless $secret;

   my $encrypted = $context->body_parameters->{event};
   my $params    = $self->_decode_params($context, $secret, $encrypted);
   my $message   = "Runid ${runid} authentication failed";

   $result = [HTTP_UNAUTHORIZED, { message => $message }];

   return $self->_stash_response($context, $result) unless $params;

   my $daemon_pid = $self->config->appclass->env_var('daemon_pid');

   try {
      my $event = $self->schema->resultset('Event')->create($params);

      $message = 'Event ' . $event->id . ' created';
      $result  = [HTTP_CREATED, { message => $message }];
      trigger_input_handler($self->config);
   }
   catch { $result = [HTTP_BAD_REQUEST, { message => "${_}" }] };

   $self->_stash_response($context, $result);
   return;
}

sub create_job : Auth('none') {
   my ($self, $context) = @_;

   my $request = $context->request;
   my $result;

   try   { $request->authenticate_headers }
   catch { $result = [HTTP_BAD_REQUEST, { message => "${_}" }] };

   return $self->_stash_response($context, $result) if $result;

   my $session_id = $context->stash('session_id');
   my $session;

   try   { $session = $self->get_session($session_id) }
   catch { $result = [HTTP_NOT_FOUND, { message => "${_}" } ] };

   return $self->_stash_response($context, $result) if $result;

   my $secret    = $session->{shared_secret};
   my $encrypted = $context->body_parameters->{job};
   my $params    = $self->_decode_params($context, $secret, $encrypted);
   my $message   = "Session ${session_id} authentication failed";

   $result = [HTTP_UNAUTHORIZED, { message => $message }];

   return $self->_stash_response($context, $result) unless $params;

   $params->{owner_id} = $session->{user_id};
   $params->{group_id} = $session->{role_id};

   try {
      my $job = $self->schema->resultset('Job')->create($params);

      $result = [HTTP_CREATED, { message => 'Job ' . $job->id . ' created' } ];
   }
   catch { $result = [HTTP_BAD_REQUEST, { message => "${_}" }] };

   $self->_stash_response($context, $result);
   return;
}

# Private methods
sub _decode_params {
   my ($self, $context, $secret, $encrypted) = @_;

   my $params;

   try   { $params = $self->json_parser->decode(decrypt $secret, $encrypted) }
   catch { $self->log->error($_, $context) };

   return $params;
}

sub _stash_response {
   my ($self, $context, $result) = @_;

   $result //= [];

   my $code = $result->[0] // HTTP_OK;
   my $body = $result->[1] // {};

   $self->log->error($body->{message}, $context) if is_error($code);

   $context->stash(code => $code, json => $body, view => 'json');
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
