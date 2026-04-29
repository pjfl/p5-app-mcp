package App::MCP::Table::View::User;

use HTML::StateTable::Constants qw( FALSE SPC TRUE );
use Moo;

extends 'App::MCP::Table::View::Object';

has '+caption' => default => 'View User';

has '+form_buttons' => default => sub {
   my $self    = shift;
   my $context = $self->context;
   my $user_id = $self->result->id;

   return [{
      action    => $context->uri_for_action('user/list'),
      classes   => 'left',
      method    => 'get',
      selection => 'disable_on_select',
      value     => 'Users',
   },{
      action    => $context->uri_for_action('user/profile', [$user_id]),
      method    => 'get',
      selection => 'disable_on_select',
      value     => 'Settings',
   },{
      action    => $context->uri_for_action('user/edit', [$user_id]),
      method    => 'get',
      selection => 'disable_on_select',
      value     => 'Edit',
   }];
};

sub BUILD {
   my $self    = shift;
   my $context = $self->context;

   push @{$self->add_columns}, '2FA Enabled' => {
      cell_traits => ['Bool'],
      value       => $self->result->enable_2fa,
   };

   push @{$self->add_columns}, 'Advanced' => {
      cell_traits => ['Bool'],
      value       => $self->result->enable_advanced,
   };

   push @{$self->add_columns}, 'Time Zone' => $self->result->timezone;

   push @{$self->add_columns}, 'Groups' =>
      join SPC, map { ucfirst } @{$self->result->groups // []};

   return;
}

use namespace::autoclean;

1;
