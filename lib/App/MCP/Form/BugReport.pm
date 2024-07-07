package App::MCP::Form::BugReport;

use HTML::Forms::Constants qw( FALSE META TRUE );
use Moo;
use HTML::Forms::Moo;

extends 'HTML::Forms::Model::DBIC';
with    'HTML::Forms::Role::Defaults';

has '+name'         => default => 'BugReport';
has '+title'        => default => 'Bug Report';
has '+info_message' => default => 'Report a bug';
has '+item_class'   => default => 'Bug';

has_field 'description' => type => 'TextArea', required => TRUE;

has_field 'user_id' => type => 'Hidden';

has_field 'submit' => type => 'Button';

sub validate {
   my $self = shift;

   $self->field('user_id')->value($self->context->session->id);

   return;
}

use namespace::autoclean -except => META;

1;
