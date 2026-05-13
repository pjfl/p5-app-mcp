package App::MCP::Model::Worker;

use App::MCP::Constants   qw( EXCEPTION_CLASS FALSE TRUE );
use HTTP::Status          qw( HTTP_BAD_REQUEST HTTP_CREATED HTTP_NOT_FOUND
                              HTTP_OK HTTP_UNAUTHORIZED );
use App::MCP::Util        qw( trigger_input_handler );
use Unexpected::Functions qw( throw );
use Try::Tiny;
use Moo;
use App::MCP::Attributes; # Will do namespace cleaning

extends 'App::MCP::Model';
with    'Web::Components::Role';
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

   my $runid   = $context->stash('runid');
   my $token   = $self->_get_decode_token($runid);
   my $message = "Runid ${runid} token not found";

   $result = [HTTP_NOT_FOUND, { message => $message }] unless $token;

   return $self->_stash_response($context, $result) if $result;

   my $event  = $request->body_params->('event');
   my $params = $self->decode_params($token, $event);

   $message = "Runid ${runid} authentication failed";
   $result  = [HTTP_UNAUTHORIZED, { message => $message }] unless $params;

   return $self->_stash_response($context, $result) if $result;

   my $pid    = $self->config->appclass->env_var('daemon_pid');
   my $schema = $self->schema;

   try {
      $event  = $schema->resultset('Event')->create($params);
      $result = [HTTP_CREATED, { message => 'Event '.$event->id.' created' }];
      trigger_input_handler $pid;
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

   my $key        = $session->{key};
   my $secret     = $session->{shared_secret};
   my $encrypted  = $request->body_params->('job');
   my $params     = $self->decode_params($key, $secret, $encrypted);
   my $message    = "Session ${session_id} authentication failed";

   $result  = [HTTP_UNAUTHORIZED, { message => $message }] unless $params;

   return $self->_stash_response($context, $result) if $result;

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
sub _get_decode_token {
   my ($self, $runid) = @_;

   my $options = { columns => ['token'], rows => 1 };
   my $pev_rs  = $self->schema->resultset('ProcessedEvent');
   my $pevent  = $pev_rs->search({ runid => $runid }, $options)->single;

   return $pevent ? $pevent->token : undef;
}

sub _stash_response {
   my ($self, $context, $result) = @_;

   $result //= [];

   my $code = $result->[0] // HTTP_OK;
   my $json = $result->[1] // {};

   $context->stash(code => $code, json => $json, view => 'json');
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
