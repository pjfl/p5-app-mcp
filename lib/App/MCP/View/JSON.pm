# @(#)Ident: JSON.pm 2014-01-24 14:36 pjf ;

package App::MCP::View::JSON;

use namespace::sweep;

use Moo;
use Class::Usul::Types qw( Object );
use JSON               qw( );

# Private attributes
has '_transcoder' => is => 'lazy', isa => Object, builder => sub { JSON->new };

# Public methods
sub render {
   my ($self, $req, $stash) = @_;

   my $content = $self->_transcoder->encode( $stash->{content} );

   return [ $stash->{code}, __header(), [ $content ] ];
}

# Private functions
sub __header {
   return [ 'Content-Type' => 'application/json' ];
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
