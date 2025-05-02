package App::MCP::Form::Register;

use HTML::Forms::Constants qw( EXCEPTION_CLASS FALSE META TRUE );
use App::MCP::Util         qw( create_token redirect );
use Unexpected::Functions  qw( catch_class );
use Try::Tiny;
use Moo;
use HTML::Forms::Moo;

extends 'HTML::Forms';
with    'HTML::Forms::Role::Defaults';
with    'App::MCP::Role::SendMessage';

has '+name'         => default => 'Register';
has '+title'        => default => 'Registration Request';
has '+info_message' => default => 'Answer the registration questions';
has '+item_class'   => default => 'User';
has '+no_update'    => default => TRUE;

has_field 'user_name' => label => 'User Name', required => TRUE;

has_field 'email' =>
   type                => 'Email',
   required            => TRUE,
   validate_inline     => TRUE,
   validate_when_empty => TRUE;

has_field 'submit' => type => 'Button';

after 'after_build_fields' => sub {
   my $self = shift;
   my $attr = $self->field('user_name')->element_attr;

   $attr->{minlength} = $self->context->config->user->{min_name_len};
   return;
};

sub validate {
   my $self   = shift;
   my $rs     = $self->context->model($self->item_class);
   my $config = $self->context->config;
   my $name   = $self->field('user_name');
   my $email  = $self->field('email');

   $name->add_error('User name [_1] not unique', [$name->value])
      if $rs->find({ name => $name->value });

   $name->add_error('User name [_1] too short', [$name->value])
      if length $name->value < $config->user->{min_name_len};

   $email->add_error('Email address [_1] not unique', [$email->value])
      if $rs->find({ email => $email->value });

   return if $self->result->has_errors;

   try {
      $self->context->stash(job => $self->_create_email($name, $email));
   }
   catch_class [
      '*' => sub {
         $self->add_form_error($_);
         $self->log->alert($_, $self->context) if $self->has_log;
      }
   ];

   return;
}

sub _create_email {
   my ($self, $name, $email) = @_;

   my $token   = create_token;
   my $context = $self->context;
   my $link    = $context->uri_for_action('page/register', [$token]);
   my $passwd  = substr create_token, 0, 12;
   my $options = {
      application => $context->config->name,
      email       => $email->value,
      link        => "${link}",
      password    => $passwd,
      recipients  => [$email->value],
      subject     => 'User Registration',
      template    => 'register_user.md',
      username    => $name->value,
   };

   return $self->send_message($context, $token, $options);
}

use namespace::autoclean -except => META;

1;
