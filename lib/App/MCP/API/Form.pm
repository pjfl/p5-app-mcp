package App::MCP::API::Form;

use Class::Usul::Cmd::Constants qw( EXCEPTION_CLASS FALSE NUL TRUE );
use Unexpected::Types           qw( Str );
use Unexpected::Functions       qw( throw );
use Moo;
use App::MCP::Attributes; # Will do namespace cleaning

has 'name' => is => 'ro', isa => Str, required => TRUE;

sub field : Auth('none') {
   my ($self, $context, $field_name, $operation) = @_;

   my $result = { reason => 'Unknown operation' };

   if ($operation eq 'validate') {
      my $value   = $context->request->query_parameters->{value};
      my $options = { context => $context };
      my $name    = $self->name; $name =~ s{ _ }{::}gmx;
      my $form    = $context->models->{page}->new_form($name, $options);
      my $field   = $form->field($field_name);

      $form->setup_form({ $field_name => $value });
      $field->validate_field;
      $result = { reason => [$field->result->all_errors] };
   }

   $context->stash(json => $result);
   return;
}

1;
