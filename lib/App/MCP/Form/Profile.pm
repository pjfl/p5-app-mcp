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
has '+title'                  => default => 'User Settings';
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

has_field 'display_options' => type => 'Group';

has_field 'skin' =>
   type        => 'Select',
   field_group => 'display_options',
   options     => [
      { label => 'Default', value => 'default' },
      { label => 'None',    value => 'none' },
   ];

sub default_skin {
   return shift->context->config->skin;
}

has_field 'theme' =>
   type        => 'Select',
   default     => 'system-theme',
   field_group => 'display_options',
   options     => [
      { label => 'Dark',   value => 'dark-theme' },
      { label => 'Light',  value => 'light-theme' },
      { label => 'System', value => 'system-theme' },
];

has_field 'menu_options' => type => 'Group';

has_field 'menu_location' =>
   type        => 'Select',
   default     => 'header',
   field_group => 'menu_options',
   label       => 'Menu Location',
   options     => [
      { label => 'Header',  value => 'header' },
      { label => 'Sidebar', value => 'sidebar' },
   ];

has_field 'link_display' =>
   type          => 'Select',
   default       => 'both',
   field_group   => 'menu_options',
   label         => 'Link Display',
   wrapper_class => 'input-select shrink',
   options       => [
      { label => 'Both', value => 'both' },
      { label => 'Icon', value => 'icon' },
      { label => 'Text', value => 'text' },
   ];

has_field 'advanced_options' => type => 'Group', info => 'Advanced Options';

has_field 'features' =>
   type             => 'Select',
   auto_widget_size => 5,
   field_group      => 'advanced_options',
   multiple         => TRUE,
   size             => 4,
   options          => [
      { label => 'Animation',        value => 'animation' },
      { label => 'Droplets',         value => 'droplets' },
      { label => 'Notifications',    value => 'notifications' },
      { label => 'Radar',            value => 'radar' },
      { label => 'Relative Colours', value => 'relative' },
      { label => 'Tooltips',         value => 'tooltips' },
   ];

has_field 'base_colour' =>
   type        => 'Colour',
   field_group => 'advanced_options',
   label       => 'Base Colour',
   options     => [];

has_field 'submit' => type => 'Button';

has_field 'view' =>
   type          => 'Link',
   label         => 'View',
   element_class => ['form-button'],
   wrapper_class => [qw(input-button inline)];

after 'after_build_fields' => sub {
   my $self    = shift;
   my $context = $self->context;

   unless ($self->user->enable_2fa) {
      $self->field('enable_2fa')->hide_info(TRUE);
      $self->field('mobile_phone')->add_wrapper_class('hide');
      $self->field('postcode')->add_wrapper_class('hide');
   }

   $self->field('advanced_options')->inactive(TRUE)
      unless $context->config->enable_advanced;

   my $field  = $self->field('base_colour');
   my $colour = $context->config->default_base_colour;

   $field->default($colour);
   push @{$field->options}, { value => $colour };

   my $view = $self->context->uri_for_action('user/view', [$self->user->id]);

   $self->field('view')->href($view->as_string);
   $self->field('submit')->add_wrapper_class(['inline', 'right']);

   return;
};

sub update_model {
   my $self   = shift;
   my $user   = $self->user;
   my $value  = $user->profile_value;
   my @fields = (qw(base_colour enable_2fa features link_display menu_location
                    mobile_phone postcode skin theme timezone));

   for my $field_name (@fields) {
      $value->{$field_name} = $self->field($field_name)->value;
   }

   my $session = $self->context->session;

   $self->update_session($session, $value) if $session->id == $user->id;

   $user->totp_secret($value->{enable_2fa});
   $value->{enable_2fa} = json_bool $value->{enable_2fa};

   $self->context->model('Preference')->update_or_create({
      name => 'profile', user_id => $user->id, value => $value
   }, {
      key  => 'preferences_user_id_name_uniq'
   });

   return;
}

use namespace::autoclean -except => META;

1;
