package App::MCP::Model::Documentation;

use App::MCP::Constants    qw( EXCEPTION_CLASS FALSE TRUE );
use File::DataClass::Types qw( Path );
use File::DataClass::IO    qw( io );
use App::MCP::Util         qw( redirect );
use App::MCP::File::Docs::View;
use Moo;
use App::MCP::Attributes; # Will do cleaning

extends 'App::MCP::Model';
with    'Web::Components::Role';
with    'App::MCP::Role::FileMeta';

has '+moniker' => default => 'doc';

has 'local_library' =>
   is      => 'ro',
   isa     => Path,
   default => sub { io((split m{ : }mx, $ENV{PERL5LIB})[-1]) };

has '_doc_viewer' =>
   is      => 'ro',
   default => sub { App::MCP::File::Docs::View->new() };

sub base : Auth('view') {
   my ($self, $context) = @_;

   $context->stash('nav')->finalise;

   return;
}

sub application : Auth('view') Nav('Application') {
   my ($self, $context) = @_;

   my $options   = {
      caption    => 'Application Documentation',
      context    => $context,
      file_home  => $self->file_home,
      file_share => $self->file_share,
   };
   my $params    = $context->request->query_parameters;
   my $directory = $params->{directory};
   my $selected  = $params->{selected};

   unless ($directory || $selected) {
      $directory = 'App';
      $selected  = 'MCP.pm';
   }

   $options->{directory} = $directory if $directory;
   $options->{selected}  = $selected  if $selected;

   $context->stash(table => $self->new_table('Docs', $options));

   return unless $selected;

   $directory = $self->file->directory($directory);

   my $path   = $directory->catfile($selected);
   my $markup = $self->_doc_viewer->get($context, $path);

   $context->stash(documentation => $markup);
   return;
}

sub configuration : Auth('admin') Nav('Configuration') {
   my ($self, $context) = @_;

   my $form = $self->new_form('Configuration', { context => $context });

   $context->stash(form => $form);
   return;
}

sub server : Auth('view') Nav('Server') {
   my ($self, $context) = @_;

   my $locallib = $self->local_library;
   my $params   = $context->request->query_parameters;
   my $options  = {
      action      => 'doc/server',
      action_view => 'doc/server',
      caption     => 'Server Documentation',
      context     => $context,
      file_home   => $locallib,
      file_share  => $self->file_share,
   };
   my $directory = $params->{directory};
   my $selected  = $params->{selected};

   $options->{directory} = $directory if $directory;
   $options->{selected}  = $selected  if $selected;

   $context->stash(table => $self->new_table('Docs', $options));

   return unless $selected;

   $directory = $locallib->catdir($self->file->to_path($params->{directory}));

   my $path   = $directory->catfile($selected);
   my $markup = $self->_doc_viewer->get($context, $path);

   $context->stash(documentation => $markup);
   return;
}

1;
