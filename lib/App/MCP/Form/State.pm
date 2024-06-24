package App::MCP::Form::State;

use HTML::Forms::Constants qw( FALSE META NUL TRUE USERID );
use HTML::Forms::Types     qw( Int );
use Scalar::Util           qw( blessed );
use Try::Tiny;
use Moo;
use HTML::Forms::Moo;

extends 'HTML::Forms::Model::DBIC';
with    'HTML::Forms::Role::Defaults';

has '+name'                => default => 'state-diagram';
has '+title'               => default => 'State';
has '+default_wrapper_tag' => default => 'fieldset';
has '+do_form_wrapper'     => default => TRUE;
has '+info_message'        => default => 'You know what to do';
has '+is_html5'            => default => TRUE;
has '+item_class'          => default => 'Job';

has_field 'submit' => type => 'Button';

sub validate {
   my $self = shift;

   return if $self->result->has_errors;

   my $field = $self->field('filter_json');

   try { $self->item->parse($field->value) }
   catch {
      $self->add_form_error(blessed $_ ? $_->original : "${_}");
      $self->log->alert($_, $self->context) if $self->has_log;
   };

   return;
}

use namespace::autoclean -except => META;

1;
