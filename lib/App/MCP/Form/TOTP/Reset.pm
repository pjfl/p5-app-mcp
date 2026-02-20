package App::MCP::Form::TOTP::Reset;

use HTML::Forms::Constants qw( EXCEPTION_CLASS FALSE META NUL TRUE );
use Class::Usul::Cmd::Util qw( includes );
use App::MCP::Util         qw( create_token redirect );
use Type::Utils            qw( class_type );
use Unexpected::Functions  qw( catch_class );
use Try::Tiny;
use Moo;
use HTML::Forms::Moo;

extends 'HTML::Forms';
with    'HTML::Forms::Role::Defaults';

has '+info_message' => default => 'Answer the security questions';
has '+name'         => default => 'TOTP_Reset';
has '+title'        => default => 'OTP Reset';

has 'config' => is => 'lazy', default => sub { shift->context->config };

has 'user' =>
   is       => 'ro',
   isa      => class_type('App::MCP::Schema::Schedule::Result::User'),
   required => TRUE;

with 'App::MCP::Role::Redis';
with 'App::MCP::Role::JSONParser';
with 'App::MCP::Role::SendMessage';

has_field 'name' => type => 'Display', label => 'User Name';

sub default_name {
   my $user = shift->user; return "${user}";
}

has_field 'password' => type => 'Password', required => TRUE;

has_field 'mobile_phone' =>
   type          => 'PosInteger',
   label         => 'Mobile #',
   required      => TRUE,
   size          => 12;

sub validate_mobile_phone {
   my $self  = shift;
   my $field = $self->field('mobile_phone');
   my $value = $field->value;

   $field->add_error($value ? 'Invalid response' : 'Required')
      unless $value && $value == $self->user->mobile_phone;

   return;
}

has_field 'postcode' => required => TRUE, size => 8;

sub validate_postcode {
   my $self  = shift;
   my $field = $self->field('postcode');
   my $value = $field->value;

   $field->add_error($value ? 'Invalid response' : 'Required')
      unless $value && $value eq $self->user->postcode;

   return;
}

has_field 'submit' => type => 'Button';

after 'after_build_fields' => sub {
   my $self    = shift;
   my $session = $self->context->session;

   $self->add_form_wrapper_class('narrow');

   $self->add_form_element_class('droplets')
      if includes 'droplets', $session->features;

   $self->add_form_element_class('radar')
      if includes 'radar', $session->features;

   return;
};

sub validate {
   my $self   = shift;
   my $user   = $self->user;
   my $passwd = $self->field('password');

   try {
      $user->authenticate($passwd->value, NUL, TRUE);
      $user->assert_can_email;
   }
   catch_class [
      'Authentication' => sub { $passwd->add_error($_->original) },
      '*' => sub {
         $self->add_form_error($_->original);
         $self->log->alert($_->original, $self->context) if $self->has_log;
      }
   ];

   return;
}

sub update_model {
   my $self    = shift;
   my $user    = $self->user;
   my $token   = create_token;
   my $context = $self->context;
   my $actionp = 'misc/totp_reset';
   my $link    = $context->uri_for_action($actionp, [$user->id, $token]);
   my $params  = {
      application => $context->config->name,
      link        => "${link}",
      recipients  => [$user->id],
      subject     => 'OTP Authenticator Reset',
      template    => 'totp_reset.md',
   };
   my $payload = $self->json_parser->encode($params);
   my $cache   = $self->redis_client;

   $cache->set_with_ttl("totp_reset-${token}", $payload, 86400);
   $context->stash(job => $self->send_message($context, $token, $payload));
   return;
}

use namespace::autoclean -except => META;

1;
