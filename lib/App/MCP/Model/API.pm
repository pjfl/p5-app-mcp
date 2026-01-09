package App::MCP::Model::API;

use App::MCP::Constants   qw( DOT EXCEPTION_CLASS FALSE TRUE );
use HTTP::Status          qw( HTTP_BAD_REQUEST HTTP_CREATED
                              HTTP_NOT_FOUND HTTP_OK);
use App::MCP::Util        qw( trigger_input_handler );
use Unexpected::Functions qw( throw );
use DateTime::TimeZone;
use Try::Tiny;
use Moo;
use App::MCP::Attributes; # Will do namespace cleaning

extends 'App::MCP::Model';
with    'Web::Components::Role';
with    'App::MCP::Role::APIAuthentication';

has '+moniker' => default => 'api';

sub diagram : Auth('none') Capture(1) {
   my ($self, $context, $name) = @_;

   $context->stash(diagram_name => $name);
   return;
}

sub form : Auth('none') Capture(1) {
   my ($self, $context, $name) = @_;

   $name =~ s{ _ }{::}gmx;

   $context->stash(form => $self->new_form($name, { context => $context }));
   return;
}

sub field : Auth('none') Capture(1) {
   my ($self, $context, $name) = @_;

   $context->stash(field => $context->stash('form')->field($name));
   return;
}

sub object : Auth('none') Capture(1) {
   my ($self, $context, $name) = @_;

   $context->stash(object_name => $name);
   return;
}

sub table : Auth('none') Capture(1) {
   my ($self, $context, $name) = @_;

   $context->stash(table_name => $name);
   return;
}

sub runid : Auth('none') Capture(1) {
   my ($self, $context, $name) = @_;

   $context->stash(runid => $name);
   return;
}

sub sessionid : Auth('none') Capture(1) {
   my ($self, $context, $name) = @_;

   $context->stash(sessionid => $name);
   return;
}

sub action : Auth('view') {
   my ($self, $context) = @_;

   my $data = $context->get_body_parameters->{data};
   my ($moniker, $method) = split m{ / }mx, $data->{action};

   if (exists $context->models->{$moniker}) {
      try   { $context->models->{$moniker}->execute($context, $method) }
      catch { $self->log->error($_, $context) };
   }
   else { $self->log->error("Model ${moniker} unknown", $context) }

   $self->_stash_result($context);
   return;
}

sub collect_messages : Auth('none') {
   my ($self, $context) = @_;

   my $session  = $context->session;
   my $messages = $session->collect_status_messages($context->request);

   $self->_stash_result($context, [ reverse @{$messages} ]);
   return;
}

sub create_event : Auth('none') {
   my ($self, $context) = @_;

   my $request = $context->request;

   $request->authenticate_headers;

   my $schema = $self->schema;
   my $run_id = $context->stash('runid');
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

   my $result = { message => 'Event ' . $event->id . ' created' };

   $context->stash(code => HTTP_CREATED, json => $result, view => 'json');
   return;
}

sub create_job : Auth('none') {
   my ($self, $context) = @_;

   my $request = $context->request;

   $request->authenticate_headers;

   my $session_id = $context->stash('session_id');
   my $session    = $self->get_session($session_id);
   my $params     = $self->authenticate_params(
      $session->{key}, $session->{shared_secret}, $request->body_params->('job')
   );
   my $job;

   $params->{owner_id} = $session->{user_id};
   $params->{group_id} = $session->{role_id};

   try    { $job = $self->schema->resultset('Job')->create($params) }
   catch  { throw $_, rv => HTTP_BAD_REQUEST };

   my $result = { message => 'Job ' . $job->id . ' created' };

   $context->stash(code => HTTP_CREATED, json => $result, view => 'json');
   return;
}

sub fetch : Auth('none') {
   my ($self, $context) = @_;

   my $name   = $context->stash('object_name');
   my $method = "_fetch_${name}";
   my $result = {};

   if ($self->can($method)) {
      try   { $result = $self->$method($context) }
      catch { $self->log->error($_, $context) };
   }
   else { $self->log->error("Object ${name} unknown", $context) }

   $self->_stash_result($context, $result);
   return;
}

sub preference : Auth('view') {
   my ($self, $context) = @_;

   my $name  = $self->_preference_name($context);
   my $value = $context->get_body_parameters->{data} if $context->posted;
   my $pref  = $self->_preference($context, $name, $value);

   $self->_stash_result($context, $pref ? $pref->value : {});
   return;
}

sub validate : Auth('none') {
   my ($self, $context) = @_;

   my $form  = $context->stash('form');
   my $field = $context->stash('field');
   my $value = $context->request->query_parameters->{value};

   $form->setup_form({ $field->name => $value });
   $field->validate_field;
   $self->_stash_result($context, { reason => [$field->result->all_errors] });
   return;
}

# Private methods
sub _fetch_list_name {
   my ($self, $context) = @_;

   my $list_id = $context->request->query_parameters->{list_id};

   return { list_name => $context->model('List')->find($list_id)->name };
}

sub _fetch_property {
   my ($self, $context) = @_;

   my $request = $context->request;
   my $class   = $request->query_params->('class');
   my $prop    = $request->query_params->('property');
   my $value   = $request->query_params->('value', { raw => TRUE });
   my $result  = { found => \0 };

   return $result unless defined $value;

   my $r = $context->model($class)->find_by_key($value);

   $result->{found} = \1 if $r && $r->execute($prop);

   return $result;
}

sub _fetch_timezones {
   return { timezones => [DateTime::TimeZone->all_names] };
}

sub _preference { # Accessor/mutator with builtin clearer. Store "" to delete
   my ($self, $context, $name, $value) = @_;

   return unless $name;

   my $rs = $context->model('Preference');

   return $rs->update_or_create({ # Mutator
      name => $name, user_id => $context->session->id, value => $value
   }, { key => 'preferences_user_id_name_uniq' }) if $value && $value ne '""';

   my $pref = $rs->find({
      name => $name, user_id => $context->session->id
   }, { key => 'preferences_user_id_name_uniq' });

   return $pref->delete if defined $pref && defined $value; # Clearer

   return $pref; # Accessor
}

sub _preference_name {
   my ($self, $context) = @_;

   return 'diagram' . DOT . $context->stash('diagram_name') . DOT . 'preference'
      if $context->stash('diagram_name');

   return 'table' . DOT . $context->stash('table_name') . DOT . 'preference';
}

sub _stash_result {
   my ($self, $context, $result) = @_;

   $result //= {};
   $context->stash(code => HTTP_OK, json => $result, view => 'json');
   return;
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
