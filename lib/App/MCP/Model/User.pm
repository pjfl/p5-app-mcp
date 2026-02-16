package App::MCP::Model::User;

use App::MCP::Constants   qw( EXCEPTION_CLASS FALSE TRUE );
use App::MCP::Util        qw( redirect redirect2referer );
use Unexpected::Functions qw( UnauthorisedAccess UnknownUser Unspecified );
use Moo;
use App::MCP::Attributes; # Will do namespace cleaning

extends 'App::MCP::Model';
with    'Web::Components::Role';

has '+moniker' => default => 'user';

sub base : Auth('view') {
   my ($self, $context) = @_;

   $context->stash('nav')->list('user')->item('user/create')->finalise;

   return;
}

sub user : Auth('view') Capture(1) {
   my ($self, $context, $userid) = @_;

   my $session = $context->session;
   my $args    = { username => $userid, options => { prefetch => 'profile' } };
   my $user    = $context->find_user($args, $session->realm);

   return $self->error($context, UnknownUser, [$userid]) unless $user;

   return $self->error($context, UnauthorisedAccess)
      unless $user->is_authorised($session, ['admin', 'manager']);

   $context->stash(user => $user);

   my $nav = $context->stash('nav')->list('user')->item('user/create');

   $nav->crud('user', $user->id)->finalise;
   return;
}

sub create : Auth('admin') Nav('Create User') {
   my ($self, $context) = @_;

   my $options = { context => $context, title => 'Create User' };
   my $form    = $self->new_form('User', $options);

   if ($form->process(posted => $context->posted)) {
      my $view    = $context->uri_for_action('user/view', [$form->item->id]);
      my $message = 'User [_1] created';

      $context->stash(redirect $view, [$message, $form->item->user_name]);
   }

   $context->stash(form => $form);
   return;
}

sub delete : Auth('admin') Nav('Delete User') {
   my ($self, $context) = @_;

   return unless $self->verify_form_post($context);

   my $user = $context->stash->{user};
   my $name = $user->user_name;

   $user->delete;

   my $list = $context->uri_for_action('user/list');

   $context->stash(redirect $list, ['User [_1] deleted', $name]);
   return;
}

sub edit : Auth('admin') Nav('Edit User') {
   my ($self, $context) = @_;

   my $user    = $context->stash->{user};
   my $options = { context => $context, item => $user, title => 'Edit User' };
   my $form    = $self->new_form('User', $options);

   if ($form->process(posted => $context->posted)) {
      my $params  = { 'current-page' => $form->current_page };
      my $edit    = $context->uri_for_action('user/edit', [$user->id], $params);
      my $message = 'User [_1] updated';

      $context->stash(redirect $edit, [$message, $form->item->user_name]);
   }

   $context->stash(form => $form);
   return;
}

sub profile : Auth('view') Nav('Settings') {
   my ($self, $context) = @_;

   my $user = $context->stash('user');

   return $self->error($context, UnauthorisedAccess)
      if $context->posted && !$user->is_authorised($context->session,['admin']);

   my $form = $self->new_form('Profile', { context => $context, user => $user});

   if ($form->process(posted => $context->posted)) {
      my $location = $context->uri_for_action('user/profile', [$user->id]);
      my $message  = ['User [_1] profile updated', $user->user_name];
      my $options  = { http_headers => { 'X-Force-Reload' => 'true' }};

      $context->stash(redirect $location, $message, $options);
   }

   $context->stash(form => $form);
   return;
}

sub list : Auth('manager') Nav('Users') {
   my ($self, $context) = @_;

   my $options = { context => $context, resultset => $context->model('User') };

   $context->stash(table => $self->new_table('User', $options));
   return;
}

sub remove : Auth('admin') {
   my ($self, $context) = @_;

   return unless $self->verify_form_post($context);

   my $value = $context->body_parameters->{data} or return;
   my $rs    = $context->model('User');
   my $count = 0;

   for my $user (grep { $_ } map { $rs->find($_) } @{$value->{selector}}) {
      $user->delete;
      $count++;
   }

   $context->stash(redirect2referer $context, ["${count} user(s) deleted"]);
   return;
}

sub totp : Auth('view') Nav('View OTP') {
   my ($self, $context) = @_;

   my $user = $context->stash('user');

   return $self->error($context, UnauthorisedAccess)
      unless $user->is_authorised($context->session, ['admin']);

   my $options = { context => $context, user => $user };

   $context->stash(form => $self->new_form('TOTP::Secret', $options));
   return;
}

sub view : Auth('manager') Nav('View User') {
   my ($self, $context) = @_;

   my $user    = $context->stash('user');
   my $buttons = [{
      action    => $context->uri_for_action('user/list'),
      classes   => 'left',
      method    => 'get',
      selection => 'disable_on_select',
      value     => 'Users',
   },{
      action    => $context->uri_for_action('user/profile', [$user->id]),
      method    => 'get',
      selection => 'disable_on_select',
      value     => 'Settings',
   },{
      action    => $context->uri_for_action('user/edit', [$user->id]),
      method    => 'get',
      selection => 'disable_on_select',
      value     => 'Edit',
   }];
   my $options = {
      add_columns  => ['Time Zone' => $user->timezone],
      caption      => 'View User',
      context      => $context,
      form_buttons => $buttons,
      result       => $user
   };

   $context->stash(table => $self->new_table('View::Object', $options));
   return;
}

1;
