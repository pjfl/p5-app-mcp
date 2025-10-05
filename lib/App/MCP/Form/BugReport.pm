package App::MCP::Form::BugReport;

use App::MCP::Constants    qw( BUG_STATE_ENUM FALSE NUL SPC TRUE );
use HTML::Forms::Constants qw( META );
use HTML::Forms::Types     qw( Bool Int Str );
use HTML::Forms::Util      qw( json_bool );
use Moo;
use HTML::Forms::Moo;

extends 'HTML::Forms::Model::DBIC';
with    'HTML::Forms::Role::Defaults';
with    'App::MCP::Role::JSONParser';

has '+item_class'    => default => 'Bug';
has '+name'          => default => 'BugReport';
has '+renderer_args' => default => sub {
   return { page_names => [qw(Details Comments Attachments)] };
};
has '+title' => default => 'Report Bug';

has 'current_page' =>
   is      => 'lazy',
   isa     => Int,
   default => sub {
      my $self = shift;

      return$self->context->request->query_parameters->{'current-page'} // 0;
   };

has 'is_editor' => is => 'ro', isa => Bool, default => FALSE;

has '_icons' =>
   is      => 'lazy',
   isa     => Str,
   default => sub { shift->context->uri_for_icons->as_string };

has_field 'id' => type => 'Display';

has_field 'title' => required => TRUE;

has_field 'description' => type => 'TextArea', required => TRUE, rows => 4;

has_field 'user_id' => type => 'Hidden', disabled => TRUE;

has_field 'owner' => type => 'Display', value => 'owner.user_name';

has_field 'created' => type => 'DateTime', readonly => TRUE;

has_field 'updated' => type => 'DateTime', readonly => TRUE;

has_field 'state' =>
   type    => 'Select',
   default => 'open',
   options => [BUG_STATE_ENUM];

has_field 'assigned' => type => 'Select', label_column => 'user_name';

sub options_assigned {
   my $self  = shift;
   my $field = $self->field('assigned');

   my $accessor; $accessor = $field->parent->full_accessor if $field->parent;

   return [ NUL, NUL, @{$self->lookup_options($field, $accessor)} ];
}

has_field 'submit1' => type => 'Button';

has_field 'comments' =>
   type                   => 'DataStructure',
   do_label               => FALSE,
   deflate_value_method   => \&_deflate_comments,
   inflate_default_method => \&_inflate_comments,
   is_row_readonly        => \&_is_row_readonly,
   tags                   => { page_break => TRUE },
   wrapper_class          => ['compound'],
   structure              => [{
      name => 'comment',
      type => 'textarea'
   }, {
      name          => 'owner',
      type          => 'display',
      readonly      => TRUE,
      tag           => 'comment',
      tagLabelLeft  => 'Written by',
   }, {
      name         => 'updated',
      type         => 'datetime',
      readonly     => TRUE,
      tag          => 'comment',
      tagLabelLeft => 'on',
   }, {
      name    => 'id',
      type    => 'hidden',
      classes => 'hide'
   }, {
      name    => 'user_id',
      type    => 'hidden',
      classes => 'hide'
   }];

has_field 'submit2' => type => 'Button';

has_field 'attachments' =>
   type                   => 'DataStructure',
   add_icon               => 'attach',
   add_title              => 'Add attachment',
   do_label               => FALSE,
   deflate_value_method   => \&_deflate_attachments,
   field_group_direction  => 'vertical',
   inflate_default_method => \&_inflate_attachments,
   is_row_readonly        => \&_is_row_readonly,
   remove_callback        => "document.getElementById('submit1').click()",
   tags                   => { page_break => TRUE },
   wrapper_class          => ['compound'],
   structure              => [{
      name   => 'thumb',
      type   => 'image',
      height => '100px',
      width  => '280px'
   }, {
      name     => 'path',
      type     => 'text',
      readonly => TRUE,
   }, {
      name         => 'owner',
      type         => 'display',
      readonly     => TRUE,
      tag          => 'thumb',
      tagLabelLeft => 'Attached by',
   }, {
      name         => 'updated',
      type         => 'datetime',
      readonly     => TRUE,
      tag          => 'thumb',
      tagLabelLeft => 'on',
   }, {
      name    => 'id',
      type    => 'hidden',
      classes => 'hide'
   }, {
      name    => 'user_id',
      type    => 'hidden',
      classes => 'hide'
   }];

after 'after_build_fields' => sub {
   my $self    = shift;
   my $context = $self->context;

   $self->renderer_args->{current_page} = $self->current_page;

   if ($self->item) {
      $self->field('updated')->inactive(TRUE) unless $self->item->updated;
      $self->field('state')->inactive(TRUE) unless $self->is_editor;
      $self->info_message([
         'Update the bug report details',
         'Update the bug report comments',
         'Files attached to the bug report'
      ]);
   }
   else {
      $self->field('id')->inactive(TRUE);
      $self->field('assigned')->inactive(TRUE);
      $self->field('created')->inactive(TRUE);
      $self->field('owner')->inactive(TRUE);
      $self->field('state')->inactive(TRUE);
      $self->field('updated')->inactive(TRUE);
      $self->info_message([
         'Enter the bug report details',
         'Enter the bug report comments',
         'Files attached to the bug report'
      ]);
   }

   my $tz = $context->session->timezone;

   $self->field('created')->time_zone($tz);
   $self->field('updated')->time_zone($tz);

   my $attachments = $self->field('attachments');

   $attachments->add_handler($self->_attach_handler) if $self->item;
   $attachments->icons($self->_icons);
   $attachments->structure->[0]->{select} = $self->_select_handler;

   $self->field('comments')->icons($self->_icons);
   return;
};

sub validate {
   my $self = shift;

   return if $self->result->has_errors;

   $self->field('user_id')->value($self->context->session->id)
      unless $self->item;

   $self->field('assigned')->value(undef)
      if $self->field('state')->value eq 'open';

   return;
}

# Private field methods
sub _attach_handler {
   my $self    = shift;
   my $context = $self->context;
   my $modal   = $context->config->wcom_resources->{modal};
   my $url     = $context->uri_for_action('bug/attach', [$self->item->id]);
   my $args    = $self->json_parser->encode({
      icons     => $self->_icons,
      noButtons => json_bool TRUE,
      title     => 'Add Attachment',
      url       => $url->as_string
   });

   return "event.preventDefault(); ${modal}.create(${args})";
}

sub _deflate_attachments {
   my ($self, $value) = @_;

   my $bug_id      = $self->form->item ? $self->form->item->id : undef;
   my $session     = $self->form->context->session;
   my $attachments = [];

   for my $item (@{$self->form->json_parser->decode($value)}) {
      next unless defined $item->{path} and length $item->{path};

      my $attachment = {
         path    => $item->{path},
         user_id => $item->{user_id} || $session->id,
      };

      $attachment->{bug_id} = $bug_id     if $bug_id;
      $attachment->{id}     = $item->{id} if $item->{id};

      push @{$attachments}, $attachment;
   }

   return $attachments;
}

sub _deflate_comments {
   my ($self, $value) = @_;

   my $session  = $self->form->context->session;
   my $comments = [];

   for my $item (@{$self->form->json_parser->decode($value)}) {
      next unless defined $item->{comment} and length $item->{comment};

      my $comment = {
         comment => $item->{comment},
         user_id => $item->{user_id} || $session->id,
      };

      $comment->{id} = $item->{id} if $item->{id};

      push @{$comments}, $comment;
   }

   return $comments;
}

sub _inflate_attachments {
   my ($self, @attachments) = @_;

   my $context = $self->form->context;
   my $values  = [];

   for my $item (@attachments) {
      my $action  = 'bug/attachment';
      my $params  = { thumbnail => 'true' };
      my $uri     = $context->uri_for_action($action, [$item->id], $params);
      my $updated = $item->updated ? $item->updated : $item->created;

      $updated->set_time_zone($context->session->timezone);

      push @{$values}, {
         id      => $item->id,
         owner   => $item->owner->user_name,
         path    => $item->path,
         thumb   => $uri->as_string,
         updated => $updated->strftime('%FT%R'),
         user_id => $item->user_id,
      };
   }

   return $self->form->json_parser->encode($values);
}

sub _inflate_comments {
   my ($self, @comments) = @_;

   my $values = [];

   for my $item (@comments) {
      my $updated = $item->updated ? $item->updated : $item->created;

      $updated->set_time_zone($self->form->context->session->timezone);

      push @{$values}, {
         comment => $item->comment,
         id      => $item->id,
         owner   => $item->owner->user_name,
         updated => $updated->strftime('%FT%R'),
         user_id => $item->user_id,
      };
   }

   return $self->form->json_parser->encode($values);
}

sub _is_row_readonly {
   my ($self, $row) = @_;

   my $username = $self->form->context->session->username;

   return $row->{owner} eq $username ? FALSE : TRUE;
}

sub _select_handler {
   my $self    = shift;
   my $context = $self->context;
   my $modal   = $context->config->wcom_resources->{modal};
   my $url     = $context->uri_for_action('bug/attachment', ['%value']);
   my $args    = $self->json_parser->encode({
      icons     => $self->_icons,
      noButtons => json_bool TRUE,
      title     => 'View Attachment',
      url       => $url->as_string
   });

   return "event.preventDefault(); ${modal}.current = ${modal}.create(${args})";
}

use namespace::autoclean -except => META;

1;
