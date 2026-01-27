package App::MCP::Form::User;

use HTML::Forms::Constants qw( FALSE META TRUE );
use HTML::Forms::Types     qw( Int Str );
use Data::Validate::IP     qw( is_ip );
use Moo;
use HTML::Forms::Moo;

extends 'HTML::Forms::Model::DBIC';
with    'HTML::Forms::Role::Defaults';
with    'App::MCP::Role::JSONParser';

has '+item_class' => default => 'User';
has '+title'      => default => 'User';

has 'config' => is => 'lazy', default => sub { shift->context->config };

has 'current_page' =>
   is      => 'rw',
   isa     => Int,
   lazy    => TRUE,
   default => sub {
      my $self = shift;

      return $self->context->request->query_parameters->{'current-page'} // 0;
   };

has 'resultset' =>
   is      => 'lazy',
   default => sub {
      my $self = shift;

      return $self->context->model($self->item_class);
   };

has '_icons' =>
   is      => 'lazy',
   isa     => Str,
   default => sub { shift->context->icons_uri->as_string };

has_field 'user_name', required => TRUE;

sub validate_user_name {
   my $self = shift;
   my $name = $self->field('user_name');

   $name->add_error("User name '[_1]' too short", $name->value || '<empty>')
      if length $name->value < $self->config->user->{min_name_len};

   $name->add_error("User name '[_1]' not unique", $name->value || '<empty>')
      if !$self->item && $self->resultset->find({ user_name => $name->value });

   return;
}

has_field 'email' => type => 'Email', required => TRUE;

sub validate_email {
   my $self  = shift;
   my $email = $self->field('email');

   $email->add_error("Email address '[_1]' not unique", $email->value)
      if !$self->item && $self->resultset->find({ email => $email->value });

   return;
}

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
   my $self   = shift;
   my $user   = $self->context->model($self->item_class)->new_result({});

   return $user->encrypt_password($self->config->user->{default_password});
}

has_field 'password_expired' => type => 'Boolean', default => TRUE;

has_field 'submit1' =>
   type          => 'Button',
   value         => '1',
   wrapper_class => ['input-button'];

has_field 'view' =>
   type          => 'Link',
   label         => 'View',
   element_class => ['form-button pageload'],
   wrapper_class => ['input-button', 'inline'];

has_field 'valid_ips' =>
   type                   => 'DataStructure',
   do_label               => FALSE,
   deflate_value_method   => \&_deflate_addresses,
   inflate_default_method => \&_inflate_addresses,
   tags                   => { page_break => TRUE },
   structure              => [
      { classes => 'ipaddress', name => 'range-start', type => 'text' },
      { classes => 'ipaddress', name => 'range-end',   type => 'text' },
   ];

sub validate_valid_ips {
   my $self  = shift;
   my $field = $self->field('valid_ips');

   for my $range (@{$self->_deflate_addresses($field->value)}) {
      for my $key (grep { $range->{$_} } keys %{$range}) {
         $field->add_error('Bad IP address') unless is_ip($range->{$key});
      }
   }

   return;
}

has_field 'submit2' => type => 'Button', value => '2';

before 'before_build_fields' => sub {
   my $self = shift;

   if (my $page = $self->context->button_pressed) {
      $self->current_page($page - 1);
   }

   return;
};

after 'after_build_fields' => sub {
   my $self    = shift;
   my $context = $self->context;

   $self->renderer_args->{current_page} = $self->current_page;
   $self->renderer_args->{page_names}   = ['Details', 'IP Addresses'];
   $self->info_message([
      'With great power comes great responsibilty',
      'Enter an IP address or address range to restrict access',
   ]);

   my $user_name = $self->field('user_name');

   $user_name->element_attr->{minlength} = $self->config->user->{min_name_len};

   if ($self->item) {
      my $view = $context->uri_for_action('user/view', [$self->item->id]);

      $self->field('view')->href($view->as_string);
      $self->field('submit1')->add_wrapper_class(['inline', 'right']);
   }
   else { $self->field('view')->inactive(TRUE) }

   $self->field('valid_ips')->icons($self->_icons);

   return;
};

# Private methods
sub _deflate_addresses {
   my ($self, $value) = @_;

   return $value ? $self->form->json_parser->decode($value) : [];
}

sub _inflate_addresses {
   my ($self, $addresses) = @_;

   return $self->form->json_parser->encode($addresses || []);
}

use namespace::autoclean -except => META;

1;
