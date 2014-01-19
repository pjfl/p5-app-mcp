# @(#)Ident: PageConfiguration.pm 2014-01-19 02:17 pjf ;

package App::MCP::Role::PageConfiguration;

use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 27 $ =~ /\d+/gmx );

use Moo::Role;

requires qw( config load_page );

# Construction
around 'load_page' => sub {
   my ($orig, $self, $req, @args) = @_;

   my $page = $orig->( $self, $req, @args ); my $conf = $self->config;

   $page->{ $_ } = $conf->$_() for (qw( author description keywords ));

   return $page;
};

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
