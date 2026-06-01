package App::MCP::EventStream;

use App::MCP::Constants     qw( FALSE TRUE );
use Class::Usul::Cmd::Types qw( ConfigProvider HashRef Int Logger );
use Class::Usul::Cmd::Util  qw( ensure_class_loaded );
use Web::Components::Util   qw( load_components );
use Try::Tiny;
use Moo;

=pod

=encoding utf-8

=head1 Name

App::MCP::EventStream - Master Control Program - Event stream

=head1 Synopsis

   use App::MCP::EventStream;

=head1 Description

Event stream processing

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=item C<config>

=cut

has 'config' => is => 'ro', isa => ConfigProvider, required => TRUE;

=item C<log>

=cut

has 'log' => is => 'ro', isa => Logger, required => TRUE;

=item C<plugins>

=cut

has 'plugins' =>
   is      => 'lazy',
   isa     => HashRef,
   default => sub { load_components 'Plugin', { application => shift } };

=item C<service_worker_lifetime>

=cut

has 'service_worker_lifetime' => is => 'ro', isa => Int, default => 7_776_000;

with 'App::MCP::Role::Redis';
with 'App::MCP::Role::JSONParser';
with 'App::MCP::Role::Webpush';

=back

=head1 Subroutines/Methods

Defineds the following methods;

=over 3

=cut

=item C<register>

   $message = $self->register($id, \%subscription);

=cut

sub register {
   my ($self, $id, $subscription) = @_;

   my $key = "event_subscription-${id}";

   if ($subscription->{method} eq 'unregister') {
      $self->redis_client->del($key);
      return "User ${id} event registration deleted";
   }

   $subscription->{id} = $id;

   my $encoded = $self->json_parser->encode($subscription);
   my $ttl     = $self->service_worker_lifetime;

   $self->redis_client->set_with_ttl($key, $encoded, $ttl);

   return "User ${id} event registration created";
}

=item C<register_plugins>

   $self->register_plugins;

=cut

sub register_plugins {
   my $self = shift;

   for my $moniker (keys %{$self->plugins}) {
      next unless $self->config->plugins->{$moniker};

      my $subscription = { method => 'callback', plugin => $moniker };
      my $message      = $self->register($moniker, $subscription);

      $self->log->info("EventStream: ${message}");
   }

   return;
}

=item C<send_to_subscribers>

   $self->send_to_subscribers($name, $payload);

=cut

sub send_to_subscribers {
   my ($self, $name, $payload) = @_;

   my $log = $self->log;

   for my $key ($self->redis_client->keys('event_subscription-*')) {
      my $subscription = $self->_get_subscription($key) or next;
      my $method       = '_event_stream_' . $subscription->{method};

      next unless $self->can($method);

      $subscription->{id} = (split m{ \- }mx, $key)[1];

      try {
         my $res    = $self->$method($name, $subscription, $payload);
         my $leader = "${name}." . $subscription->{method};

         $log->error("${leader}: " . $res->{error})   unless $res->{success};
         $log->debug("${leader}: " . $res->{message}) if     $res->{success};
      }
      catch { $log->error("${name}.send_to_subscribers: ${_}") };
   }

   return;
}

# Private methods
sub _get_subscription {
   my ($self, $key) = @_;

   my $cache   = $self->redis_client;
   my $encoded = $cache->get($key) or return;
   my $subscription;

   try   { $subscription = $self->json_parser->decode($encoded) }
   catch { $cache->del($key) };

   return $subscription;
}

sub _event_stream_callback {
   my ($self, $name, $subscription, $payload) = @_;

   my $moniker  = $subscription->{plugin};
   my $callback = $self->plugins->{$moniker};

   return $callback->post($payload);
}

sub _event_stream_webpost {
   my ($self, $name, $subscription, $payload) = @_;

   my $uri = $subscription->{callback_uri};

   return $self->web_server_post($uri, $payload);
}

sub _event_stream_webpush {
   my ($self, $name, $subscription, $payload) = @_;

   return $self->service_worker_push($subscription->{id}, $payload);
}

use namespace::autoclean;

1;

__END__

=back

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Moo>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module. Please report problems to
http://rt.cpan.org/NoAuth/Bugs.html?Dist=App-MCP.
Patches are welcome

=head1 Acknowledgements

Larry Wall - For the Perl programming language

=head1 Author

Peter Flanigan, C<< <pjfl@cpan.org> >>

=head1 License and Copyright

Copyright (c) 2026 Peter Flanigan. All rights reserved

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See L<perlartistic>

This program is distributed in the hope that it will be useful,
but WITHOUT WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE

=cut

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
