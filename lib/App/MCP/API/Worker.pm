package App::MCP::API::Worker;

use App::MCP::Constants   qw( EXCEPTION_CLASS FALSE NUL TRUE );
use HTTP::Status          qw( HTTP_BAD_REQUEST HTTP_CREATED HTTP_NOT_FOUND );
use Unexpected::Types     qw( Str );
use App::MCP::Util        qw( trigger_input_handler );
use Unexpected::Functions qw( throw );
use Try::Tiny;
use Moo;
use App::MCP::Attributes; # Will do namespace cleaning

with 'App::MCP::Role::Config';
with 'App::MCP::Role::Log';
with 'App::MCP::Role::APIAuthentication';

has 'name' => is => 'ro', isa => Str; # username or runid

# Public methods
sub create_event : Auth('none') {
   my ($self, $context) = @_;

   my $request = $context->request;

   $request->authenticate_headers;

   my $schema = $self->schema;
   my $run_id = $self->name;
   my $pe_rs  = $schema->resultset('ProcessedEvent')->search(
      { runid => $run_id }, { columns => ['token'] }
   );
   my $pevent = $pe_rs->single
      or throw 'Runid [_1] not found', [$run_id, rv => HTTP_NOT_FOUND];
   my $params = $self->authenticate_params(
      $run_id, $pevent->token, $request->body_params->('event')
   );
   my $event;

   try    { $event = $schema->resultset('Event')->create($params) }
   catch  { throw $_, rv => HTTP_BAD_REQUEST };

   trigger_input_handler $self->config->appclass->env_var('daemon_pid');

   my $content = { message => 'Event ' . $event->id . ' created' };

   $context->stash(code => HTTP_CREATED, json => $content);
   return;
}

sub create_job : Auth('none') {
   my ($self, $context) = @_;

   my $request = $context->request;

   $request->authenticate_headers;

   my $session_id = $self->name;
   my $session    = $self->get_session($session_id);
   my $params     = $self->authenticate_params(
      $session->{key}, $session->{shared_secret}, $request->body_params->('job')
   );
   my $job;

   $params->{owner_id} = $session->{user_id};
   $params->{group_id} = $session->{role_id};

   try    { $job = $self->schema->resultset('Job')->create($params) }
   catch  { throw $_, rv => HTTP_BAD_REQUEST };

   my $content = { message => 'Job ' . $job->id . ' created' };

   $context->stash(code => HTTP_CREATED, json => $content);
   return;
}

1;
