package App::MCP::Form::User;

use HTML::Forms::Constants qw( FALSE META TRUE );
use Moo;
use HTML::Forms::Moo;

extends 'HTML::Forms::Model::DBIC';
with    'HTML::Forms::Role::Defaults';

has '+title'        => default => 'User';
has '+info_message' => default => 'With great power comes great responsibilty';
has '+item_class'   => default => 'User';

has_field 'user_name', required => TRUE;

has_field 'email' => type => 'Email', required => TRUE;

has_field 'role' => type => 'Select', default => 2, label_column => 'role_name';

sub options_role {
   my $self  = shift;
   my $field = $self->field('role');

   my $accessor; $accessor = $field->parent->full_accessor if $field->parent;

   my $options = $self->lookup_options($field, $accessor);

   return [ map { ucfirst } @{$options} ];
}

has_field 'active' => type => 'Boolean', default => TRUE;

has_field 'password';

sub default_password {
   my $self = shift;
   my $user = $self->context->model($self->item_class)->new_result({});

   return $user->encrypt_password($self->context->config->default_password);
}

has_field 'password_expired' => type => 'Boolean', default => TRUE;

has_field 'submit' => type => 'Button';

use namespace::autoclean -except => META;

1;
