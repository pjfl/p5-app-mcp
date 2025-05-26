package App::MCP::API::Table;

use Class::Usul::Cmd::Constants qw( DOT EXCEPTION_CLASS FALSE TRUE );
use Unexpected::Types           qw( Str );
use Unexpected::Functions       qw( throw UnknownModel );
use Moo;
use App::MCP::Attributes; # Will do namespace cleaning

has 'name' => is => 'ro', isa => Str, required => TRUE;

sub action : Auth('view') {
   my ($self, $context, @args) = @_;

   return unless $context->posted;

   my $data = $context->get_body_parameters->{data};
   my ($moniker, $method) = split m{ / }mx, $data->{action};

   throw UnknownModel, [$moniker] unless exists $context->models->{$moniker};

   $context->models->{$moniker}->execute($context, $method);
   return;
}

sub preference : Auth('view') {
   my ($self, $context, @args) = @_;

   my $name   = $self->_preference_name;
   my $value  = $context->get_body_parameters->{data} if $context->posted;
   my $pref   = $self->_preference($context, $name, $value);
   my $result = $pref ? $pref->value : {};

   $context->stash(json => $result);
   return;
}

# Private methods
sub _preference { # Accessor/mutator with builtin clearer. Store "" to delete
   my ($self, $context, $name, $value) = @_;

   return unless $name;

   my $rs = $context->model('Preference');

   return $rs->update_or_create({ # Mutator
      name => $name, user_id => $context->session->id, value => $value
   }, { key => 'preference_user_id_name_uniq' }) if $value && $value ne '""';

   my $pref = $rs->find({
      name => $name, user_id => $context->session->id
   }, { key => 'preference_user_id_name_uniq' });

   return $pref->delete if defined $pref && defined $value; # Clearer

   return $pref; # Accessor
}

sub _preference_name {
   return 'table' . DOT . shift->name . DOT . 'preference';
}

1;
