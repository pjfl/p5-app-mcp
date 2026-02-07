package App::MCP::Form::ChangePassword;

use HTML::Forms::Constants qw( FALSE META TRUE );
use HTML::Forms::Util      qw( make_handler );
use Try::Tiny;
use Moo;
use HTML::Forms::Moo;

extends 'HTML::Forms::Model::DBIC';
with    'HTML::Forms::Role::Defaults';

has '+title'        => default => 'Change Password';
has '+info_message' => default => 'Authenticate using your old password';
has '+no_update'    => default => TRUE;

has_field 'user_name' =>
   type          => 'Display',
   element_class => 'tile',
   label         => 'User Name';

has_field 'old_password' =>
   type     => 'Password',
   label    => 'Old Password',
   required => TRUE;

has_field 'password' =>
   type     => 'Password',
   label    => 'New Password',
   required => TRUE,
   tags     => { reveal => TRUE };

has_field '_password' =>
   type           => 'PasswordConf',
   label          => 'and again',
   password_field => 'password',
   tags           => { reveal => TRUE };

has_field 'submit' => type => 'Button';

after 'after_build_fields' => sub {
   my $self      = shift;
   my $config    = $self->context->config;
   my $field     = $self->field('password');
   my $util      = $config->wcom_resources->{form_util};
   my $change_js = "${util}.passwordStrength";
   my $options   = { allow_default => TRUE, id => 'password' };
   my $min       = $config->user->{min_password_len};

   $field->add_handler('input', make_handler($change_js, $options));
   $field->element_attr->{minlength} = $min;
   $field->element_attr->{title} = "Must be at least ${min} characters long";
   return;
};

sub validate {
   my $self = shift;

   return unless $self->validated;

   my $old = $self->field('old_password')->value;
   my $new = $self->field('password')->value;

   return $self->add_form_error('Old and new passwords are the same')
      if $old eq $new;

   try   { $self->item->set_password($old, $new) }
   catch {
      my $exception = $_;

      $self->field('old_password')->add_error($exception->original);

      $self->log->alert($exception, $self->context) if $self->has_log;
   };

   return;
}

use namespace::autoclean -except => META;

1;
