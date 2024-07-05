package App::MCP::Form::BugReport;

use HTML::Forms::Constants qw( FALSE META TRUE );
use Type::Utils            qw( class_type );
use Moo;
use HTML::Forms::Moo;

extends 'HTML::Forms';
with    'HTML::Forms::Role::Defaults';

has '+title'                  => default => 'Bug Report';
has '+default_wrapper_tag'    => default => 'fieldset';
has '+do_form_wrapper'        => default => TRUE;
has '+info_message'           => default => 'Report a bug';
has '+use_init_obj_over_item' => default => TRUE;

has '+init_object' => default => sub {
   my $self = shift;
   my $user = $self->user;

   return {
      user_name => $user->user_name,
   };
};

has 'user' =>
   is       => 'ro',
   isa      => class_type('App::MCP::Schema::Schedule::Result::User'),
   required => TRUE;

has_field 'user_name' => type => 'Display', label => 'User Name';

has_field 'description' => type => 'TextArea', required => TRUE;

has_field 'submit' => type => 'Button';

sub validate {
   my $self = shift;

   return;
}

use namespace::autoclean -except => META;

1;
