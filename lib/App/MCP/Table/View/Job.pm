package App::MCP::Table::View::Job;

use HTML::StateTable::Constants qw( FALSE TRUE );
use Moo;

extends 'App::MCP::Table::View::Object';

has '+caption' => default => 'View Job';

has '+form_buttons' => default => sub {
   my $self    = shift;
   my $context = $self->context;
   my $id      = $self->result->id;

   return [{
      action    => $context->uri_for_action('job/list'),
      classes   => 'left',
      method    => 'get',
      selection => 'disable_on_select',
      value     => 'Jobs',
   },{
      action    => $context->uri_for_action('history/runlist', [$id]),
      classes   => 'left',
      method    => 'get',
      selection => 'disable_on_select',
      value     => 'Runs',
   },{
      action    => $context->uri_for_action('job/edit', [$id]),
      method    => 'get',
      selection => 'disable_on_select',
      value     => 'Edit',
   }];
};

use namespace::autoclean;

1;
