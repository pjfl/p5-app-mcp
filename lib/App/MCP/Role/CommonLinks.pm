# @(#)Ident: CommonLinks.pm 2014-01-19 02:17 pjf ;

package App::MCP::Role::CommonLinks;

use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 23 $ =~ /\d+/gmx );

use Moo::Role;

requires qw( config get_stash );

around 'get_stash' => sub {
   my ($orig, $self, $req, @args) = @_;

   my $stash = $orig->( $self, $req, @args ); my $conf = $self->config;

   for (@{ $conf->common_links }) {
      $stash->{links}->{ $_ } = $req->uri_for( $conf->$_() );
   }

   return $stash;
};

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
