package App::MCP::View::JSON;

use Moo;

with 'Web::Components::Role';
with 'App::MCP::Role::JSONParser';

has '+moniker' => default => 'json';

sub serialize {
   my ($self, $context) = @_;

   my $stash = $context->stash;
   my $body; $body = $stash->{body} if $stash->{body};

   $body = $self->json_parser->encode($stash->{json}) unless $body;

   return [ $stash->{code}, _header($stash->{http_headers}), [$body] ];
}

sub _header {
   return [ 'Content-Type' => 'application/json', @{ $_[0] // [] } ];
}

use namespace::autoclean;

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
