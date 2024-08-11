package App::MCP::Model::Bug;

use App::MCP::Constants   qw( EXCEPTION_CLASS FALSE TRUE );
use App::MCP::Util        qw( redirect );
use Unexpected::Functions qw( UnauthorisedAccess UnknownBug );
use Moo;
use App::MCP::Attributes; # Will do cleaning

extends 'App::MCP::Model';
with    'Web::Components::Role';

has '+moniker' => default => 'bug';

sub base : Auth('none') {
   my ($self, $context, $bugid) = @_;

   my $nav = $context->stash('nav')->list('bugs');

   if ($bugid) {
      my $rs  = $context->model('Bug');
      my $bug = $rs->find($bugid, { prefetch => [qw(comments)]});

      return $self->error($context, UnknownBug, [$bugid]) unless $bug;

      $context->stash(bug => $bug);
      $nav->crud('bug', $bugid);
   }

   $nav->finalise;
   return;
}

sub create : Auth('view') Nav('Report Bug') {
   my ($self, $context) = @_;

   my $form = $self->new_form('BugReport', { context => $context });

   if ($form->process(posted => $context->posted)) {
      my $bugid    = $form->item->id;
      my $username = $context->session->username;
      my $view     = $context->uri_for_action('bug/view', [$bugid]);
      my $message  = ['User [_1] bug report [_2] created', $username, $bugid];

      $context->stash(redirect $view, $message);
   }

   $context->stash(form => $form);
   return;
}

sub delete : Auth('admin') Nav('Delete Bug') {
   my ($self, $context) = @_;

   return unless $self->verify_form_post($context);

   my $bug   = $context->stash('bug');
   my $bugid = $bug->id;

   $bug->delete;

   my $list = $context->uri_for_action('bug/list');

   $context->stash(redirect $list, ['Bug report [_1] deleted', $bugid]);
   return;
}

sub edit : Nav('Update Bug') {
   my ($self, $context) = @_;

   my $bug       = $context->stash('bug');
   my $session   = $context->session;
   my $is_owner  = $session->id == $bug->user_id ? TRUE : FALSE;
   my $is_editor = ($session->role eq 'manager' or $session->role eq 'admin')
                 ? TRUE : FALSE;

   return $self->error($context, UnauthorisedAccess, [])
      unless $is_editor || $is_owner;

   my $options = {
      context      => $context,
      info_message => 'Edit bug details',
      is_editor    => $is_editor,
      item         => $bug,
      title        => 'Update Bug',
   };
   my $form = $self->new_form('BugReport', $options);

   if ($form->process(posted => $context->posted)) {
      my $username = $context->session->username;
      my $view     = $context->uri_for_action('bug/view', [$form->item->id]);
      my $message  = ['Bug report [_1] updated', $form->item->id];

      $context->stash(redirect $view, $message);
   }

   $context->stash(form => $form);
   return;
}

sub list : Auth('view') Nav('Bugs') {
   my ($self, $context) = @_;

   my $table = $self->new_table('Bugs', { context => $context });

   $context->stash(table => $table);
   return;
}

sub view : Auth('view') Nav('View Bug') {
   my ($self, $context) = @_;

   my $bug = $context->stash('bug');
   my $buttons = [{
      action    => $context->uri_for_action('bug/edit', [$bug->id]),
      method    => 'get',
      selection => 'disable_on_select',
      value     => 'Update',
   },{
      action    => $context->uri_for_action('bug/delete', [$bug->id]),
      classes   => 'right',
      selection => 'disable_on_select',
      value     => 'Delete',
   }];
   my $options = {
      caption      => 'View Bug',
      context      => $context,
      form_buttons => $buttons,
      result       => $bug,
   };

   $context->stash(table => $self->new_table('Object::View', $options));
   return;
}

1;
