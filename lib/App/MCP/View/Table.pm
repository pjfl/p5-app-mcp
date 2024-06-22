package App::MCP::View::Table;

use Moo;

extends 'HTML::StateTable::View::Serialise';
with    'Web::Components::Role';

has '+moniker' => default => 'table';

sub serialize {
   my ($self, $context) = @_;

   $self->process($context);

   my $response = $context->response;

   return [ $context->stash->{code}, [$response->header], [$response->body] ];
}

use namespace::autoclean;

1;
