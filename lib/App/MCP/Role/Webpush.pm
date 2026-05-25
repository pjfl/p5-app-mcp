package App::MCP::Role::Webpush;

use App::MCP::Constants    qw( FALSE NUL TRUE );
use File::DataClass::Types qw( Int );
use Type::Utils            qw( class_type );
use HTTP::Request::Webpush;
use HTTP::Tiny;
use Moo::Role;

requires qw( json_parser redis_client );

=pod

=encoding utf-8

=head1 Name

App::MCP::Role::Webpush - A client role for the browser Web Push API

=head1 Synopsis

   use Moo;

   with 'App::MCP::Role::Webpush';

=head1 Description

A client role for the browser Web Push API

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=item C<ua_timeout>

Defaults to thirty seconds. How long should the HTTP user agent wait for
responses

=cut

has 'ua_timeout' => is => 'ro', isa => Int, default => 30;

# Private attributes
has '_pusher' =>
   is      => 'lazy',
   isa     => class_type('HTTP::Request::Webpush'),
   default => sub {
      my $self   = shift;
      my $pusher = HTTP::Request::Webpush->new;

      if (my $encoded = $self->redis_client->get('service-worker-keys')) {
         my $keys = $self->json_parser->decode($encoded);

         $pusher->authbase64($keys->{public}, $keys->{private});
      }

      return $pusher;
   };

has '_ua' =>
   is      => 'lazy',
   isa     => class_type('HTTP::Tiny'),
   default => sub { HTTP::Tiny->new(timeout => shift->ua_timeout) };

=back

=head1 Subroutines/Methods

Defineds the following methods;

=over 3

=item C<service_worker_push>

   $hash_ref = $self->service_worker_push($user_id, \%content);

If a user with the given C<user_id> has registered a Web Push subscription push
the supplied C<content>

Returns a hash reference with the C<success> attribute set to true if
successful. Returns a hash reference containing an C<error> attribute
otherwise

=cut

sub service_worker_push {
   my ($self, $user_id, $content) = @_;

   return { error => "Parameter 'user_id' not specified" } unless $user_id;

   $content //= { message => 'Something happened' };

   my $worker_key   = "service-worker-${user_id}";
   my $subscription = $self->redis_client->get($worker_key);
   my $message      = "User '${user_id}' no service worker subscription";

   return { error => $message } unless $subscription;

   my $req = $self->_pusher;

   $req->subscription($self->json_parser->decode($subscription));
   $req->subject('mailto:mcp@example.com');
   $req->content($self->json_parser->encode($content));
   $req->header('TTL' => '90');
   $req->encode();
   $req->remove_header('::std_case'); # Strange artifact

   my $params  = { content => $req->content, headers => $req->headers };
   my $res     = $self->_ua->post($req->uri, $params);

   return $self->decode_response($res);
}

=item C<web_server_post>

   $hash_ref = $self->web_server_post($uri, \%content);

Returns a hash reference with the C<success> attribute set to true if
successful. Returns a hash reference containing an C<error> attribute
otherwise

=cut

sub web_server_post {
   my ($self, $uri, $content) = @_;

   return { error => "Parameter 'uri' not specified" } unless $uri;

   $content //= { message => 'Something happened' };

   my $encoded = $self->json_parser->encode($content);
   my $headers = { 'Content-Type' => 'application/json' };
   my $params  = { content => $encoded, headers => $headers };
   my $res     =  $self->_ua->post($uri, $params);

   return $self->decode_response($res);
}

use namespace::autoclean;

1;

__END__

=back

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<HTTP::Request::Webpush>

=item L<HTTP::Tiny>

=item L<Moo::Role>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module. Please report problems to
http://rt.cpan.org/NoAuth/Bugs.html?Dist=App-MCP.  Patches are welcome

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
