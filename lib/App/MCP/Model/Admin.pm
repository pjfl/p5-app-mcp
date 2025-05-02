package App::MCP::Model::Admin;

use Moo;
use App::MCP::Attributes; # Will do namespace cleaning

extends 'App::MCP::Model';
with    'Web::Components::Role';

has '+moniker' => default => 'admin';

sub menu : Auth('admin') Nav('Admin|img/admin.svg') {
   my ($self, $context) = @_;

   my $nav = $context->stash('nav')->list('admin');

   $nav->menu('page')->item('page/configuration');
   $nav->menu('doc')->item('doc/list');
   $nav->menu('logfile')->item('logfile/list');
   $nav->menu('user')->item('user/list');
   return;
}

1;
