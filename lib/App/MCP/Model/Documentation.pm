package App::MCP::Model::Documentation;

use App::MCP::Constants    qw( EXCEPTION_CLASS FALSE TRUE );
use File::DataClass::Types qw( Directory Path Str );
use App::MCP::Util         qw( redirect );
use App::MCP::File::Docs::View;
use Moo;
use App::MCP::Attributes; # Will do cleaning

extends 'App::MCP::Model';
with    'Web::Components::Role';

has '+moniker' => default => 'doc';

has 'extensions' => is => 'ro', isa => Str, default => 'pm';

has 'meta_home' => is => 'ro', isa => Directory, required => TRUE;

has 'meta_share' => is => 'ro', isa => Path, required => TRUE;

has '_doc_viewer' =>
   is      => 'ro',
   default => sub { App::MCP::File::Docs::View->new() };

with 'App::MCP::Role::FileMeta';

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

   my $options   = {
      context    => $context,
      extensions => $self->extensions,
      meta_home  => $self->meta_home,
      meta_share => $self->meta_share,
   };
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
   my $directory = $self->meta_directory($params->{directory});
   my $markup    = $self->_doc_viewer->get($directory->catfile($file));

   $context->stash(documentation => $markup);
   return;
}

1;
