package App::MCP::EventStream;

use App::MCP::Constants     qw( FALSE TRUE );
use Class::Usul::Cmd::Types qw( ConfigProvider Logger );
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

with 'App::MCP::Role::Redis';
with 'App::MCP::Role::JSONParser';
with 'App::MCP::Role::Webpush';

=back

=head1 Subroutines/Methods

Defineds the following methods;

=over 3

=item C<send_to_subscribers>

   $self->send_to_subscribers($name, $payload);

=cut

sub send_to_subscribers {
   my ($self, $name, $payload) = @_;

   my $cache = $self->redis_client;

   for my $key ($cache->keys('event_subscription-*')) {
      my $encoded = $cache->get($key) or next;
      my $subscription;

      try   { $subscription = $self->json_parser->decode($encoded) }
      catch { $cache->del($key) };

      next unless $subscription;

      my $method = '_event_stream_' . $subscription->{method};

      next unless $self->can($method);

      $subscription->{user_id} = (split m{ \- }mx, $key)[1];

      try   { $self->$method($name, $subscription, $payload) }
      catch { $self->log->error("${name}.send_to_subscribers: ${_}") };
   }

   return;
}

# Private methods
sub _event_stream_callback {
   # TODO: Implement event stream output method for a callback
   my ($self, $name, $subscription, $payload) = @_;

   my $leader = ucfirst "${name}.callback";

   return;
}

sub _event_stream_webpost {
   my ($self, $name, $subscription, $payload) = @_;

   my $leader = ucfirst "${name}.webpost";
   my $uri    = $subscription->{callback_uri};
   my $res    = $self->web_server_post($uri, $payload);

   $self->log->error("${leader}: " . $res->{error}) unless $res->{success};
   $self->log->debug("${leader}: " . $res->{message}) if $res->{success};
   return;
}

sub _event_stream_webpush {
   my ($self, $name, $subscription, $payload) = @_;

   my $leader  = ucfirst "${name}.webpush";
   my $user_id = $subscription->{user_id};
   my $res     = $self->service_worker_push($user_id, $payload);

   $self->log->error("${leader}: " . $res->{error}) unless $res->{success};
   $self->log->debug("${leader}: " . $res->{message}) if $res->{success};
   return;
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
