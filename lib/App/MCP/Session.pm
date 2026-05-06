package App::MCP::Session;

use App::MCP::Constants     qw( FALSE TRUE );
use Class::Usul::Cmd::Types qw( ConfigProvider );
use Plack::Session::State::Cookie;
use Plack::Session::Store::Cache;
use Moo;

with 'App::MCP::Role::JSONParser';

=pod

=encoding utf-8

=head1 Name

App::MCP::Session - Session store and configuration

=head1 Synopsis

   use App::MCP::Session;

=head1 Description

Session store and configuration

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=item C<config>

A required reference to the L<configuration|App::MCP::Config> object

=cut

has 'config' => is => 'ro', isa => ConfigProvider, required => TRUE;

with 'App::MCP::Role::Redis';

has '+redis_client_name' => default => 'session_store';

=back

=head1 Subroutines/Methods

Defines the following methods;

=over 3

=item C<middleware_config>

   $session_config = $self->middleware_config;

Provides configuration for the L<state cookie|Plack::Session::State::Cookie>
and the L<session store|Plack::Session::Store::Cache>

=cut

sub middleware_config {
   my $self   = shift;
   my $config = $self->_hash2list($self->config->state_cookie);

   return (
      state => Plack::Session::State::Cookie->new(@{$config}),
      store => Plack::Session::Store::Cache->new(cache => $self)
   );
}

=item C<get>

   $value = $self->get($key);

=cut

sub get {
   my ($self, $key) = @_;

   return $self->json_parser->decode($self->redis_client->get($key));
}

=item C<remove>

   $value = $self->remove($key);

=cut

sub remove {
   my ($self, $key) = @_;

   return $self->redis_client->del($key);
}

=item C<set>

   $value = $self->set($key, $value);

=cut

sub set {
   my ($self, $key, $value) = @_;

   return $self->redis_client->set($key, $self->json_parser->encode($value));
}

# Private methods
sub _hash2list {
   my ($self, $hash) = @_;

   my $list = [];

   for my $key (keys %{$hash}) {
      push @{$list}, $key, $hash->{$key};
   }

   return $list;
}

use namespace::autoclean;

1;

__END__

=back

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<App::MCP::Role::JSONParser>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module. Please report problems to
http://rt.cpan.org/NoAuth/Bugs.html?Dist=App::MCP.
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
