package App::MCP::View::JSON;

use namespace::autoclean;

use Moo;
use Class::Usul::Types qw( Object );
use JSON               qw( );

with q(App::MCP::Role::Component);

has '+moniker' => default => 'json';

# Private attributes
has '_transcoder' => is => 'lazy', isa => Object, builder => sub { JSON->new };

# Public methods
sub serialize {
   my ($self, $req, $stash) = @_;

   my $content = $self->_transcoder->encode( $stash->{content} );

   return [ $stash->{code}, __header( $stash->{http_headers} ), [ $content ] ];
}

# Private functions
sub __header {
   return [ 'Content-Type' => 'application/json', @{ $_[ 0 ] || [] } ];
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
