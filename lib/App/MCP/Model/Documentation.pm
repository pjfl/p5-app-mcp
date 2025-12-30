package App::MCP::Model::Documentation;

use App::MCP::Constants qw( EXCEPTION_CLASS FALSE TRUE );
use App::MCP::Util      qw( redirect );
use App::MCP::File::Docs::View;
use Moo;
use App::MCP::Attributes; # Will do cleaning

extends 'App::MCP::Model';
with    'Web::Components::Role';
with    'App::MCP::Role::FileMeta';

has '+moniker' => default => 'doc';

has '+meta_config_attr' => default => 'documentation';

has '_doc_viewer' =>
   is      => 'ro',
   default => sub { App::MCP::File::Docs::View->new() };

sub base {
   my ($self, $context) = @_;

   my $nav = $context->stash('nav')->list('doc');

   $nav->finalise;
   return;
}

sub configuration : Auth('admin') Nav('Configuration') {
   my ($self, $context) = @_;

   my $options = { context => $context };

   $context->stash(form => $self->new_form('Configuration', $options));
   return;
}

sub list : Nav('Docs') {
   my ($self, $context) = @_;

   my $options   = { context => $context };
   my $params    = $context->request->query_parameters;
   my $directory = $params->{directory};
   my $selected  = $params->{selected};

   $options->{directory} = $directory if $directory;
   $options->{selected}  = $selected  if $selected;

   $context->stash(table => $self->new_table('Docs', $options));
   return;
}

sub view : Nav('View Docs') {
   my ($self, $context, $file) = @_;

   my $params    = $context->request->query_parameters;
   my $directory = $self->meta_directory($context, $params->{directory});
   my $markup    = $self->_doc_viewer->get($directory->catfile($file));

   $context->stash(documentation => $markup);
   return;
}

1;
