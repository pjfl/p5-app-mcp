# @(#)Ident: Preferences.pm 2014-01-19 02:16 pjf ;

package App::MCP::Role::Preferences;

use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 27 $ =~ /\d+/gmx );

use Class::Usul::Constants;
use Class::Usul::Functions  qw( base64_decode_ns );
use Storable                qw( thaw );
use Moo::Role;

requires qw( config get_stash );

around 'get_stash' => sub {
   my ($orig, $self, $req, @args) = @_;

   my $stash  = $orig->( $self, $req, @args );
   my $params = $req->params;
   my $conf   = $self->config;
   my $cookie = $req->cookie->{ $conf->name.'_prefs' };
   my $frozen = $cookie ? base64_decode_ns( $cookie->value ) : FALSE;
   my $prefs  = $frozen ? thaw $frozen : {};

   for my $k (@{ $conf->preferences }) {
      $stash->{prefs}->{ $k }
         = $params->{ $k } // $prefs->{ $k } // $conf->$k();
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
