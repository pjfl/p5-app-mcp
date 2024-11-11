package App::MCP::Form::BugReport;

use App::MCP::Constants    qw( BUG_STATE_ENUM FALSE NUL SPC TRUE );
use HTML::Forms::Constants qw( META );
use HTML::Forms::Types     qw( Bool );
use Moo;
use HTML::Forms::Moo;

extends 'HTML::Forms::Model::DBIC';
with    'HTML::Forms::Role::Defaults';
with    'App::MCP::Role::JSONParser';

has '+name'         => default => 'BugReport';
has '+title'        => default => 'Report Bug';
has '+info_message' => default => 'Enter the bug report details';
has '+item_class'   => default => 'Bug';

has 'is_editor' => is => 'ro', isa => Bool, default => FALSE;

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

has_field 'comments' =>
   type                   => 'DataStructure',
   do_label               => FALSE,
   deflate_value_method   => \&_deflate_comments,
   inflate_default_method => \&_inflate_comments,
   is_row_readonly        => sub {
      my ($field, $row) = @_;

      my $username = $field->form->context->session->username;

      return $row->{owner} eq $username ? FALSE : TRUE;
   },
   structure              => [
      { name => 'comment', type => 'textarea', label => 'Comments' },
      { name => 'owner',   type => 'display', tag => 'comment' },
      {
         name     => 'updated',
         type     => 'datetime',
         readonly => TRUE,
         tag      => 'comment'
      },
      { name => 'id',      type => 'hidden' },
      { name => 'user_id', type => 'hidden' },
   ],
   wrapper_class => ['compound'];

has_field 'submit' => type => 'Button';

after 'after_build_fields' => sub {
   my $self = shift;

   if ($self->item) {
      $self->field('updated')->inactive(TRUE) unless $self->item->updated;
      $self->field('state')->inactive(TRUE) unless $self->is_editor;
   }
   else {
      $self->field('assigned')->inactive(TRUE);
      $self->field('created')->inactive(TRUE);
      $self->field('owner')->inactive(TRUE);
      $self->field('state')->inactive(TRUE);
      $self->field('updated')->inactive(TRUE);
   }

   my $tz = $self->context->session->timezone;

   $self->field('created')->time_zone($tz);
   $self->field('updated')->time_zone($tz);
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

# Private methods
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

use namespace::autoclean -except => META;

1;
