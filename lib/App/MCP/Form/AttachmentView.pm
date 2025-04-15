package App::MCP::Form::AttachmentView;

use HTML::Forms::Constants qw( FALSE META NUL TRUE );
use HTML::Forms::Types     qw( Object );
use Moo;
use HTML::Forms::Moo;

extends 'HTML::Forms';
with    'HTML::Forms::Role::Defaults';

has '+do_form_wrapper' => default => FALSE;
has '+info_message'    => default => NUL;
has '+name'            => default => 'BugAttachment';
has '+no_update'       => default => TRUE;

has 'attachment' => is => 'ro', isa => Object, required => TRUE;

has_field 'image' => type => 'Image', do_label => FALSE;

has_field 'cancel' =>
   html_name     => 'submit',
   label         => 'Cancel',
   type          => 'Button',
   value         => 'cancel',
   wrapper_class => ['inline input-button left'];

has_field 'download' =>
   html_name     => 'submit',
   label         => 'Download',
   type          => 'Button',
   value         => 'download',
   wrapper_class => ['inline input-button right'];

after 'after_build_fields' => sub {
   my $self    = shift;
   my $context = $self->context;
   my $id      = $self->attachment->id;
   my $params  = { thumbnail => 'true' };
   my $src     = $context->uri_for_action('bug/attachment', [$id], $params);

   $self->field('image')->src($src->as_string);

   my $resources   = $context->config->wcom_resources;
   my $modal_close = $resources->{modal} . '.current.close';
   my $js          = sprintf "%s(); %s('%s', '%s'); %s('%s'); %s()",
      'event.preventDefault',
      $resources->{downloadable} . '.downloader',
      $context->uri_for_action('bug/attachment', [$id], { download => 'true' }),
      $self->attachment->path,
      $resources->{navigation} . '.renderLocation',
      $context->uri_for_action('bug/edit', [$self->attachment->bug_id]),
      $modal_close;

   $self->field('download')->element_attr->{javascript} = { onclick => $js };

   $js = sprintf "%s(); %s()", 'event.preventDefault', $modal_close;

   $self->field('cancel')->element_attr->{javascript} = { onclick => $js };
   return;
};

use namespace::autoclean -except => META;

1;
