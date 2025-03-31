package App::MCP::API::Form;

use Class::Usul::Cmd::Constants qw( EXCEPTION_CLASS FALSE NUL TRUE );
use Unexpected::Types           qw( Str );
use Unexpected::Functions       qw( throw );
use Moo;
use App::MCP::Attributes; # Will do namespace cleaning

with 'App::MCP::Role::Config';
with 'App::MCP::Role::Redis';

has 'name' => is => 'ro', isa => Str, required => TRUE;

has '+redis_client_name' => default => 'job_stash';

sub field : Auth('none') {
   my ($self, $context, $field_name, $operation) = @_;

   my $result = { reason => 'Unknown operation' };

   if ($operation eq 'validate') {
      my $value   = $context->request->query_parameters->{value};
      my $options = { context => $context, redis => $self->redis_client };
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

sub thumbnail : Auth('view') {
   my ($self, $context, @args) = @_;
   my $path = join '/', @args;
   warn $path;
   return;
}

1;
