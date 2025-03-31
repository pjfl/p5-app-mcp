package App::MCP::Form::BugReport;

use App::MCP::Constants    qw( BUG_STATE_ENUM FALSE NUL SPC TRUE );
use HTML::Forms::Constants qw( META );
use HTML::Forms::Types     qw( Bool Str );
use HTML::Forms::Util      qw( json_bool );
use Moo;
use HTML::Forms::Moo;

extends 'HTML::Forms::Model::DBIC';
with    'HTML::Forms::Role::Defaults';
with    'App::MCP::Role::JSONParser';

has '+item_class'    => default => 'Bug';
has '+name'          => default => 'BugReport';
has '+renderer_args' => default => sub {
   return { page_names => [qw(Details Attachments Comments)] };
};
has '+title' => default => 'Report Bug';

has 'is_editor' => is => 'ro', isa => Bool, default => FALSE;

has '_icons' =>
   is      => 'lazy',
   isa     => Str,
   default => sub { shift->context->uri_for_icons->as_string };

has_field 'id' => type => 'Display';

has_field 'title' => required => TRUE;

has_field 'description' => type => 'TextArea', required => TRUE;

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

has_field 'attachments' =>
   type                   => 'DataStructure',
   do_label               => FALSE,
   inflate_default_method => \&_inflate_attachments,
   tags                   => { page_break => TRUE },
   row_class              => 'ds-row separate',
   structure              => [
      {  name => 'path', type => 'image', readonly => TRUE },
      {
         name          => 'owner',
         type          => 'display',
         readonly      => TRUE,
         tag           => 'path',
         tagLabelLeft  => 'Attached by',
      },
      {
         name         => 'updated',
         type         => 'datetime',
         readonly     => TRUE,
         tag          => 'path',
         tagLabelLeft => 'on',
      },
   ],
   wrapper_class => ['compound'];

has_field 'attach' =>
   type  => 'Button',
   label => 'attach',
   title => 'Add attachment';

has_field 'comments' =>
   type                   => 'DataStructure',
   do_label               => FALSE,
   deflate_value_method   => \&_deflate_comments,
   inflate_default_method => \&_inflate_comments,
   is_row_readonly        => \&_is_row_readonly,
   tags                   => { page_break => TRUE },
   row_class              => 'ds-row separate',
   structure              => [
      { name => 'comment', type => 'textarea' },
      {
         name         => 'updated',
         type         => 'datetime',
         readonly     => TRUE,
         tag          => 'comment',
         tagLabelLeft => 'On',
      },
      {
         name          => 'owner',
         type          => 'display',
         readonly      => TRUE,
         tag           => 'comment',
         tagLabelLeft  => 'user',
         tagLabelRight => 'wrote',
      },
      { name => 'id',      type => 'hidden', classes => 'hide' },
      { name => 'user_id', type => 'hidden', classes => 'hide' },
   ],
   wrapper_class => ['compound'];

has_field 'submit2' => type => 'Button';

after 'after_build_fields' => sub {
   my $self    = shift;
   my $context = $self->context;

   if ($self->item) {
      $self->field('updated')->inactive(TRUE) unless $self->item->updated;
      $self->field('state')->inactive(TRUE) unless $self->is_editor;
      $self->info_message([
         'Update the bug report details',
         'Files attached to the bug report',
         'Update the bug report comments'
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
         'Files attached to the bug report',
         'Enter the bug report comments'
      ]);
   }

   my $tz = $context->session->timezone;

   $self->field('created')->time_zone($tz);
   $self->field('updated')->time_zone($tz);

   my $attach = $self->field('attach');

   if ($self->item) {
      my $modal   = $context->config->wcom_resources->{modal};
      my $url     = $context->uri_for_action('bug/attach', [$self->item->id]);
      my $args    = $self->json_parser->encode({
         icons     => $self->_icons,
         noButtons => json_bool TRUE,
         title     => 'Add Attachment',
         url       => $url->as_string
      });
      my $handler = "event.preventDefault(); ${modal}.create(${args})";

      $attach->element_attr->{javascript}->{onclick} = $handler;
   }
   else { $attach->inactive(TRUE) }

   $attach->icons($self->_icons);

   $self->field('attachments')->icons($self->_icons);
   $self->field('comments')->icons($self->_icons);
   return;
};

sub validate {
   my $self = shift;

   $self->field('user_id')->value($self->context->session->id)
      unless $self->item;

   $self->field('assigned')->value(undef)
      if $self->field('state')->value eq 'open';

   return;
}

# Private field methods
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
      my $args    = [$self->form->name, $item->path];
      my $thumb   = $context->uri_for_action('api/form_thumbnail', $args);
      my $updated = $item->updated ? $item->updated : $item->created;

      $updated->set_time_zone($context->session->timezone);

      push @{$values}, {
         path    => $thumb->as_string,
         id      => $item->id,
         owner   => $item->owner->user_name,
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

use namespace::autoclean -except => META;

1;
