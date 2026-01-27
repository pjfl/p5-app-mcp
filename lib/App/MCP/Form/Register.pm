package App::MCP::Form::Register;

use HTML::Forms::Constants qw( EXCEPTION_CLASS FALSE META TRUE );
use App::MCP::Util         qw( create_token redirect );
use Class::Usul::Cmd::Util qw( includes );
use Type::Utils            qw( class_type );
use Unexpected::Functions  qw( catch_class );
use Try::Tiny;
use Moo;
use HTML::Forms::Moo;

extends 'HTML::Forms';
with    'HTML::Forms::Role::Defaults';

has '+info_message' => default => 'Answer the sign up questions';
has '+item_class'   => default => 'User';
has '+name'         => default => 'Register';
has '+title'        => default => 'Sign Up';

has 'config' => is => 'lazy', default => sub { shift->context->config };

has 'resultset' =>
   is      => 'lazy',
   default => sub {
      my $self = shift;

      return $self->context->model($self->item_class);
   };

with 'App::MCP::Role::JSONParser';
with 'App::MCP::Role::SendMessage';

has_field 'user_name' =>
   label           => 'User Name',
   required        => TRUE,
   validate_inline => TRUE;

sub validate_user_name {
   my $self = shift;
   my $name = $self->field('user_name');

   $name->add_error("User name '[_1]' too short", $name->value || '<empty>')
      if length $name->value < $self->config->user->{min_name_len};

   $name->add_error("User name '[_1]' not unique", $name->value || '<empty>')
      if $self->resultset->find({ user_name => $name->value });

   return;
}

has_field 'email' =>
   type            => 'Email',
   required        => TRUE,
   validate_inline => TRUE;

sub validate_email {
   my $self  = shift;
   my $email = $self->field('email');

   $email->add_error("Email address '[_1]' not unique", $email->value)
      if $self->resultset->find({ email => $email->value });

   return;
}

has_field 'submit' => type => 'Button';

after 'after_build_fields' => sub {
   my $self    = shift;
   my $name    = $self->field('user_name');
   my $session = $self->context->session;

   $name->element_attr->{minlength} = $self->config->user->{min_name_len};

   $self->add_form_wrapper_class('narrow');

   $self->add_form_element_class('droplets')
      if includes 'droplets', $session->features;

   $self->add_form_element_class('radar')
      if includes 'radar', $session->features;

   return;
};

sub update_model {
   my $self  = shift;
   my $name  = $self->field('user_name');
   my $email = $self->field('email');

   try { $self->context->stash(job => $self->_create_email($name, $email)) }
   catch_class [
      '*' => sub {
         $self->add_form_error($_);
         $self->log->alert("${_}", $self->context) if $self->has_log;
      }
   ];

   return;
}

sub _create_email {
   my ($self, $name, $email) = @_;

   my $token     = create_token;
   my $config    = $self->config;
   my $context   = $self->context;
   my $passwd    = substr create_token, 0, 12;
   my $link      = $context->uri_for_action('misc/register', [$token]);
   my $role_name = $config->user->{default_role} // 'view';
   my $role      = $context->model('Role')->find({ name => $role_name });
   my $options   = {
      application => $config->name,
      email       => $email->value,
      link        => "${link}",
      password    => $passwd,
      recipients  => [$email->value],
      role_id     => $role->id,
      subject     => 'User Registration',
      template    => 'register_user.md',
      username    => $name->value,
   };

   return $self->send_message($context, $token, $options);
}

use namespace::autoclean -except => META;

1;
