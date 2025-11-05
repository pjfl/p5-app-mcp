package App::MCP::Form::ChangePassword;

use HTML::Forms::Constants qw( FALSE META TRUE );
use Try::Tiny;
use Moo;
use HTML::Forms::Moo;

extends 'HTML::Forms::Model::DBIC';
with    'HTML::Forms::Role::Defaults';

has '+title'        => default => 'Change Password';
has '+info_message' => default => 'Authenticate using your old password';
has '+no_update'    => default => TRUE;

has_field 'user_name' => type => 'Display', label => 'User Name';

has_field 'old_password' =>
   type     => 'Password',
   label    => 'Old Password',
   required => TRUE;

has_field 'password' =>
   type     => 'Password',
   label    => 'New Password',
   required => TRUE,
   tags     => { reveal => TRUE },
   title    => 'Password must be at least 8 characters';

has_field '_password' =>
   type           => 'PasswordConf',
   label          => 'and again',
   password_field => 'password',
   tags           => { reveal => TRUE };

has_field 'submit' => type => 'Button';

after 'after_build_fields' => sub {
   my $self = shift;
   my $attr = $self->field('password')->element_attr;

   $attr->{minlength} = $self->context->config->user->{min_password_len};
   return;
};

sub validate {
   my $self = shift;

   return if $self->result->has_errors;
   return if $self->field('password')->has_errors;
   return if $self->field('_password')->has_errors;

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
