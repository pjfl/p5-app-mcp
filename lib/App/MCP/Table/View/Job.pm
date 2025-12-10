package App::MCP::Table::View::Job;

use HTML::StateTable::Constants qw( FALSE TRUE );
use Moo;

extends 'App::MCP::Table::View::Object';

has '+caption' => default => 'Job View';

has '+form_buttons' => default => sub {
   my $self    = shift;
   my $context = $self->context;

   return [{
      action    => $context->uri_for_action('job/edit', [$self->result->id]),
      method    => 'get',
      selection => 'disable_on_select',
      value     => 'Edit',
   },{
      action    => $context->uri_for_action('job/delete', [$self->result->id]),
      classes   => 'right',
      selection => 'disable_on_select',
      value     => 'Delete',
   }];
};

use namespace::autoclean;

1;
