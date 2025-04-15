package App::MCP::View::Image;

use HTML::Forms::Constants qw( NUL );
use Moo;

with 'Web::Components::Role';

has '+moniker' => default => 'image';

sub serialize {
   my ($self, $context) = @_;

   my $stash = $context->stash;
   my $body  = $stash->{body} // NUL;

   return [ $stash->{code}, _header($stash), [$body] ];
}

sub _header {
   my $stash = shift;
   my $type  = $stash->{mime_type} // 'image/png';

   return [ 'Content-Type' => $type, @{$stash->{http_headers} // []} ];
}

use namespace::autoclean;

1;
