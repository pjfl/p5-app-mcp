package App::MCP::Model::API;

use App::MCP::Constants   qw( DOT EXCEPTION_CLASS FALSE TRUE );
use HTTP::Status          qw( HTTP_OK );
use HTML::Forms::Util     qw( json_bool );
use MIME::Base64          qw( decode_base64url encode_base64url );
use Type::Utils           qw( class_type );
use Unexpected::Functions qw( throw );
use Crypt::PK::ECC;
use DateTime::TimeZone;
use Try::Tiny;
use Moo;
use App::MCP::Attributes; # Will do namespace cleaning

extends 'App::MCP::Model';
with    'Web::Components::Role';
with    'App::MCP::Role::Redis';
with    'App::MCP::Role::JSONParser';

has '+moniker' => default => 'api';

has '_ecc' =>
   is      => 'lazy',
   isa     => class_type('Crypt::PK::ECC'),
   default => sub {
      my $self  = shift;
      my $ecc   = Crypt::PK::ECC->new;
      my $curve = 'prime256v1';

      if (my $encoded = $self->redis_client->get('service-worker-keys')) {
         my $keys    = $self->json_parser->decode($encoded);
         my $private = decode_base64url $keys->{private};
         my $public  = decode_base64url $keys->{public};

         $ecc->import_key_raw($private, $curve);
         $ecc->import_key_raw($public, $curve);
      }
      else {
         $ecc->generate_key($curve);

         my $public  = encode_base64url $ecc->export_key_raw('public');
         my $private = encode_base64url $ecc->export_key_raw('private');
         my $keys    = { public => $public, private => $private };
         my $encoded = $self->json_parser->encode($keys);

         $self->redis_client->set('service-worker-keys', $encoded);
      }

      return $ecc;
};

sub BUILD {
   my $self = shift;

   $self->_ecc;
   return;
}

sub diagram : Auth('none') Capture(1) {
   my ($self, $context, $arg) = @_;

   $context->stash(diagram_name => $arg);
   return;
}

sub form : Auth('none') Capture(1) {
   my ($self, $context, $arg) = @_;

   $arg =~ s{ _ }{::}gmx;

   $context->stash(form => $self->new_form($arg, { context => $context }));
   return;
}

sub field : Auth('none') Capture(1) {
   my ($self, $context, $arg) = @_;

   $context->stash(field => $context->stash('form')->field($arg));
   return;
}

sub loglevel : Auth('none') Capture(1) {
   my ($self, $context, $arg) = @_;

   $context->stash(log_level => $arg);
   return;
}

sub object : Auth('none') Capture(1) {
   my ($self, $context, $arg) = @_;

   $context->stash(object_name => $arg);
   return;
}

sub table : Auth('none') Capture(1) {
   my ($self, $context, $arg) = @_;

   $context->stash(entity_name => $arg);
   return;
}

sub action : Auth('view') {
   my ($self, $context) = @_;

   my $data = $context->body_parameters->{data};
   my ($moniker, $method) = split m{ / }mx, $data->{action};

   if (exists $context->models->{$moniker}) {
      try   { $context->models->{$moniker}->execute($context, $method) }
      catch { $self->log->error($_, $context) };
   }
   else { $self->log->error("Model ${moniker} unknown", $context) }

   $self->_stash_response($context);
   return;
}

sub collect_messages : Auth('none') {
   my ($self, $context) = @_;

   my $session  = $context->session;
   my $messages = $session->collect_status_messages($context->request);

   $self->_stash_response($context, [HTTP_OK, [ reverse @{$messages} ]]);
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

   $self->_stash_response($context, [HTTP_OK, $result]);
   return;
}

sub footer : Auth('none') {
   my ($self, $context, $moniker, $method) = @_;

   $context->stash(page => { layout => 'site/footer' });

   my $action    = "${moniker}/footer";
   my $session   = $context->session;
   my $templates = $context->views->{html}->templates;
   my $footer    = $templates->catdir($session->skin)->catfile("${action}.tt");

   $context->stash(page => { layout => $action }) if $footer->exists;

   $action = "${moniker}/${method}_footer";
   $footer = $templates->catdir($session->skin)->catfile("${action}.tt");

   $context->stash(page => { layout => $action }) if $footer->exists;
   return;
}

sub logger : Auth('none') {
   my ($self, $context) = @_;

   if ($context->session->username) {
      my $level   = $context->stash('log_level');
      my $message = $context->body_parameters->{data};

      $self->log->$level($message, $context);
   }

   $self->_stash_response($context);
   return;
}

sub preference : Auth('view') {
   my ($self, $context) = @_;

   my $value  = $context->body_parameters->{data} if $context->posted;
   my $pref   = $self->_preference($context, 'table', $value);
   my $result = $pref ? $pref->value : {};

   $self->_stash_response($context, [HTTP_OK, $result]);
   return;
}

sub push_publickey : Auth('view') {
   my ($self, $context) = @_;

   my $public = $self->_ecc->export_key_raw('public');
   my $result = { publickey => encode_base64url $public };

   $self->_stash_response($context, [HTTP_OK, $result]);
   return;
}

sub push_register : Auth('view') {
   my ($self, $context) = @_;

   my $key          = $context->session->id;
   my $subscription = $context->body_parameters->{data}->{subscription};

   $subscription = $self->json_parser->encode($subscription);
   $self->redis_client->set("service-worker-${key}", $subscription);

   my $result = { text => 'Service worker registered' };

   $self->_stash_response($context, [HTTP_OK, $result]);
   return;
}

sub push_worker : Auth('none') {
   my ($self, $context) = @_;

   my @headers = ('Content-Type', 'application/javascript');
   my $jsdir   = $self->config->rootdir->catdir('js');
   my $content = $jsdir->catfile('service-worker.js')->slurp;

   $context->stash(response => [HTTP_OK, [@headers], [$content]]);
   return;
}

sub tabs_preference : Auth('view') {
   my ($self, $context) = @_;

   $context->stash(entity_name => 'tabs');

   my $value  = $context->body_parameters->{data} if $context->posted;
   my $pref   = $self->_preference($context, 'navigation', $value);
   my $result = $pref ? $pref->value : {};

   $self->_stash_response($context, [HTTP_OK, $result]);
   return;
}

sub validate : Auth('none') {
   my ($self, $context) = @_;

   my $form    = $context->stash('form');
   my $field   = $context->stash('field');
   my $params  = $context->request->query_parameters;
   my $value   = $params->{'value'};
   my $item_id = $params->{'item-id'};

   $form->setup_form(params => { $field->name => $value }, item_id => $item_id);
   $field->validate_field;

   my $result = [HTTP_OK, { reason => [$field->result->all_errors] }];

   $self->_stash_response($context, $result);
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
   my $prop    = $request->query_params->('property', { raw => TRUE });
   my $value   = $request->query_params->('value', { raw => TRUE });
   my $result  = { found => json_bool($prop =~ m{ \A ! }mx ? TRUE : FALSE) };

   return $result unless defined $value;

   $prop =~ s{ \A ! }{}mx;

   my $entity = $context->model($class)->find_by_key($value);
   my $res;

   $res = $entity->execute($prop) if $entity && $entity->can('execute');

   $result->{found} = json_bool $res if defined $res;

   return $result;
}

sub _fetch_timezones {
   return { timezones => [DateTime::TimeZone->all_names] };
}

sub _preference { # Accessor/mutator with builtin clearer. Store "" to delete
   my ($self, $context, $entity, $value) = @_;

   my $entity_name = $context->stash('entity_name') or return;
   my $name        = $entity . DOT . $entity_name . DOT . 'preference';
   my $rs          = $context->model('Preference');

   return $rs->update_or_create({ # Mutator
      name => $name, user_id => $context->session->id, value => $value
   }, { key => 'preferences_user_id_name_uniq' }) if $value && $value ne '""';

   my $pref = $rs->find({
      name => $name, user_id => $context->session->id
   }, { key => 'preferences_user_id_name_uniq' });

   return $pref->delete if defined $pref && defined $value; # Clearer

   return $pref; # Accessor
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
