package App::MCP::Model::User;

use App::MCP::Constants   qw( EXCEPTION_CLASS FALSE TRUE );
use App::MCP::Util        qw( redirect redirect2referer );
use Unexpected::Functions qw( UnauthorisedAccess UnknownUser Unspecified );
use Web::Simple;
use App::MCP::Attributes; # Will do namespace cleaning

extends 'App::MCP::Model';
with    'Web::Components::Role';

has '+moniker' => default => 'user';

sub base : Auth('view') {
   my ($self, $context, $userid) = @_;

   my $nav = $context->stash('nav')->list('user')->item('user/create');
   my $session = $context->session;

   if ($userid && ($userid == $session->id || $session->role eq 'admin')) {
      my $args = { username => $userid, options => { prefetch => 'profile' } };
      my $user = $context->find_user($args, $session->realm);

      return $self->error($context, UnknownUser, [$userid]) unless $user;

      $context->stash(user => $user);
      $nav->crud('user', $userid);
   }
   elsif ($userid) {
      return $self->error($context, UnauthorisedAccess);
   }

   $nav->finalise;
   return;
}

sub bugreport : Auth('view') Nav('Report Bug') {
   my ($self, $context) = @_;

   my $options = { context => $context, user => $context->stash->{user} };
   my $form    = $self->new_form('BugReport', $options);

   if ($form->process(posted => $context->posted)) {
      my $default = $context->uri_for_action($self->config->redirect);
      my $message = ['User [_1] bug report created', $form->user->user_name];

      $context->stash(redirect $default, $message);
   }

   $context->stash(form => $form);
   return;
}

sub create : Auth('admin') Nav('Create User') {
   my ($self, $context) = @_;

   my $options = { context => $context, title => 'Create User' };
   my $form    = $self->new_form('User', $options);

   if ($form->process( posted => $context->posted )) {
      my $view    = $context->uri_for_action('user/view', [$form->item->id]);
      my $message = ['User [_1] created', $form->item->user_name];

      $context->stash(redirect $view, $message);
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
      my $view    = $context->uri_for_action('user/view', [$user->id]);
      my $message = ['User [_1] updated', $form->item->user_name];

      $context->stash(redirect $view, $message);
   }

   $context->stash(form => $form);
   return;
}

sub profile : Auth('view') Nav('Profile') {
   my ($self, $context) = @_;

   my $user = $context->stash('user');
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

sub list : Auth('admin') Nav('Users') {
   my ($self, $context) = @_;

   my $options = { context => $context, resultset => $context->model('User') };

   $context->stash(table => $self->new_table('User', $options));
   return;
}

sub remove : Auth('admin') {
   my ($self, $context) = @_;

   return unless $self->verify_form_post($context);

   my $value = $context->request->body_parameters->{data} or return;
   my $rs    = $context->model('User');
   my $count = 0;

   for my $user (grep { $_ } map { $rs->find($_) } @{$value->{selector}}) {
      $user->delete;
      $count++;
   }

   $context->stash(redirect2referer $context, ["${count} user(s) deleted"]);
   return;
}

sub totp : Auth('view') Nav('View TOTP') {
   my ($self, $context) = @_;

   my $options = { context => $context, user => $context->stash('user') };

   $context->stash(form => $self->new_form('TOTP::Secret', $options));
   return;
}

sub view : Auth('admin') Nav('View User') {
   my ($self, $context, $userid) = @_;

   my $options = { context => $context, result => $context->stash('user') };

   $context->stash(table => $self->new_table('User::View', $options));
   return;
}

1;
