package App::MCP::View::JSON;

use HTML::Forms::Constants qw( FALSE TRUE );
use JSON::MaybeXS          qw( );
use Type::Utils            qw( class_type );
use Moo;

with 'Web::Components::Role';

has '+moniker' => default => 'json';

has '_json' =>
   is      => 'ro',
   isa     => class_type(JSON::MaybeXS::JSON),
   default => sub { JSON::MaybeXS->new( convert_blessed => TRUE ) };

sub serialize {
   my ($self, $context) = @_;

   my $stash = $context->stash;
   my $json; $json = $stash->{body} if $stash->{body};

   $json = $self->_json->encode($stash->{json}) unless $json;

   return [ $stash->{code}, _header($stash->{http_headers}), [$json] ];
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
