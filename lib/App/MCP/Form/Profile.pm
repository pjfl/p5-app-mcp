package App::MCP::Form::Profile;

use HTML::Forms::Constants qw( FALSE META TRUE );
use HTML::Forms::Types     qw( HashRef Object );
use HTML::Forms::Util      qw( json_bool );
use Type::Utils            qw( class_type );
use Moo;
use HTML::Forms::Moo;

extends 'HTML::Forms';
with    'HTML::Forms::Role::Defaults';
with    'App::MCP::Role::UpdatingSession';

has '+form_wrapper_class'     => default => sub { ['narrow'] };
has '+info_message'           => default => 'Update profile information';
has '+title'                  => default => 'User Profile';
has '+use_init_obj_over_item' => default => TRUE;

has '+init_object' => default => sub {
   my $self    = shift;
   my $user    = $self->user;
   my $profile = $user->profile;
   my $value   = $profile ? $profile->value : {};

   $value->{user_name} = $user->user_name;
   $value->{email} = $user->email;
   return $value;
};

has 'user' =>
   is       => 'ro',
   isa      => class_type('App::MCP::Schema::Schedule::Result::User'),
   required => TRUE;

has_field 'user_name' =>
   type          => 'Display',
   element_class => 'tile',
   label         => 'User Name';

has_field 'email' =>
   type          => 'Display',
   element_class => 'tile',
   label         => 'Email Address';

has_field 'timezone' => type => 'Timezone';

has_field 'enable_2fa' =>
   type   => 'Boolean',
   label  => 'Enable 2FA',
   toggle => { -checked => ['mobile_phone', 'postcode'] };

has_field 'mobile_phone' =>
   type     => 'PosInteger',
   info     =>
      'Additional security questions should be answered if 2FA is enabled',
   info_top => TRUE,
   label    => 'Mobile #',
   size     => 12,
   title    => 'Additional security question used by 2FA token reset';

has_field 'postcode' =>
   size  => 9,
   title => 'Additional security question used by 2FA token reset';

has_field '_g2' => type => 'Group';

has_field 'skin' =>
   type        => 'Select',
   field_group => '_g2',
   options     => [
      { label => 'Default', value => 'default' },
      { label => 'None',    value => 'none' },
   ];

sub default_skin {
   return shift->context->config->skin;
}

has_field 'theme' =>
   type        => 'Select',
   default     => 'light',
   field_group => '_g2',
   options     => [
      { label => 'Dark',   value => 'dark-theme' },
      { label => 'Light',  value => 'light-theme' },
      { label => 'System', value => 'system-theme' },
];

has_field '_g1' => type => 'Group';

has_field 'menu_location' =>
   type        => 'Select',
   default     => 'header',
   field_group => '_g1',
   label       => 'Menu Location',
   options     => [
      { label => 'Header',  value => 'header' },
      { label => 'Sidebar', value => 'sidebar' },
   ];

has_field 'link_display' =>
   type          => 'Select',
   default       => 'both',
   field_group   => '_g1',
   label         => 'Link Display',
   wrapper_class => 'input-select shrink',
   options       => [
      { label => 'Both', value => 'both' },
      { label => 'Icon', value => 'icon' },
      { label => 'Text', value => 'text' },
   ];

has_field '_g3' => type => 'Group', info => 'Advanced Options';

has_field 'rel_colour' =>
   type        => 'Boolean',
   field_group => '_g3',
   label       => 'Relative Colours';

has_field 'base_colour' =>
   type        => 'Colour',
   field_group => '_g3',
   label       => 'Base Colour',
   options     => [];

has_field 'bling' => type => 'Boolean', label => 'Enable Bling';

has_field 'view' =>
   type          => 'Link',
   label         => 'View',
   element_class => ['form-button'],
   wrapper_class => [qw(input-button inline)];

has_field 'submit' => type => 'Button';

after 'after_build_fields' => sub {
   my $self    = shift;
   my $context = $self->context;

   unless ($self->user->enable_2fa) {
      $self->field('enable_2fa')->hide_info(TRUE);
      $self->field('mobile_phone')->add_wrapper_class('hide');
      $self->field('postcode')->add_wrapper_class('hide');
   }

   unless ($context->config->enable_advanced) {
      $self->field('_g3')->inactive(TRUE);
      $self->field('bling')->inactive(TRUE);
   }

   my $field  = $self->field('base_colour');
   my $colour = $context->config->default_base_colour;

   $field->default($colour);
   push @{$field->options}, { value => $colour };

   my $view = $self->context->uri_for_action('user/view', [$self->user->id]);

   $self->field('view')->href($view->as_string);
   $self->field('submit')->add_wrapper_class(['inline', 'right']);

   return;
};

sub validate {
   my $self   = shift;
   my $user   = $self->user;
   my $value  = $user->profile_value;
   my @fields = (qw(base_colour bling enable_2fa link_display menu_location
                    mobile_phone postcode rel_colour skin theme timezone));

   for my $field_name (@fields) {
      $value->{$field_name} = $self->field($field_name)->value;
   }

   my $session = $self->context->session;

   $self->update_session($session, $value) if $session->id == $user->id;

   $user->totp_enable($value->{enable_2fa});
   $value->{bling}      = json_bool $value->{bling};
   $value->{enable_2fa} = json_bool $value->{enable_2fa};
   $value->{rel_colour} = json_bool $value->{rel_colour};

   $self->context->model('Preference')->update_or_create({
      name => 'profile', user_id => $user->id, value => $value
   }, {
      key  => 'preferences_user_id_name_uniq'
   });

   return;
}

use namespace::autoclean -except => META;

1;
