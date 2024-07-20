package App::MCP::Form::BugReport;

use App::MCP::Constants    qw( BUG_STATE_ENUM FALSE NUL TRUE );
use HTML::Forms::Constants qw( META );
use HTML::Forms::Types     qw( Bool );
use JSON::MaybeXS          qw( encode_json );
use Moo;
use HTML::Forms::Moo;

extends 'HTML::Forms::Model::DBIC';
with    'HTML::Forms::Role::Defaults';

has '+name'         => default => 'BugReport';
has '+title'        => default => 'Report Bug';
has '+info_message' => default => 'Enter the bug report details';
has '+item_class'   => default => 'Bug';

has 'is_editor' => is => 'ro', isa => Bool, default => FALSE;

has_field 'user_id' => type => 'Hidden';

has_field 'id' => type => 'Display', noupdate => TRUE;

has_field 'owner' =>
   type     => 'Display',
   noupdate => TRUE,
   value    => 'owner.user_name';

has_field 'created' => type => 'DateTime', readonly => TRUE;

has_field 'title' => required => TRUE;

has_field 'description' => type => 'TextArea', required => TRUE;

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
   type        => 'DataStructure',
   label       => 'Comments',
   structure   => [{
      name     => 'comment',
      type     => 'textarea',
   }];

sub default_comments {
   my $self   = shift;
   my $fields = [];

   return encode_json($fields);
}

has_field 'submit' => type => 'Button';

after 'after_build_fields' => sub {
   my $self = shift;

   if ($self->item) {
      $self->field('updated')->inactive(TRUE) unless $self->item->updated;
      $self->field('state')->inactive(TRUE) unless $self->is_editor;
   }
   else {
      $self->field('created')->inactive(TRUE);
      $self->field('owner')->inactive(TRUE);
      $self->field('state')->inactive(TRUE);
      $self->field('updated')->inactive(TRUE);
   }

   return;
};

sub validate {
   my $self = shift;

   if ($self->item) { $self->field('user_id')->value($self->item->user_id) }
   else { $self->field('user_id')->value($self->context->session->id) }

   $self->field('assigned')->value(undef)
      if $self->field('state')->value eq 'open';

   return;
}

use namespace::autoclean -except => META;

1;
