package App::MCP::Role::PageConfiguration;

use namespace::autoclean;

use Class::Usul::Constants qw( FALSE NUL TRUE );
use Class::Usul::Types     qw( ArrayRef );
use Try::Tiny;
use Moo::Role;

requires qw( config initialise_stash load_page log );

# Private attributes
has '_js_files' => is => 'lazy', isa => ArrayRef, builder => sub {
   my $self  = shift;
   my $match = sub { m{ \b \d+ [_] .+? \.js \z }mx };
   my $dir   = $self->config->root->catdir( $self->config->js );

   return [ map { $_->filename } $dir->filter( $match )->all ];
};

# Construction
around 'initialise_stash' => sub {
   my ($orig, $self, $req, @args) = @_;

   my $stash  = $orig->( $self, $req, @args ); my $conf = $self->config;

   my $params = $req->query_params; my $sess = $req->session;

   for my $k (@{ $conf->stash_attr->{session} }) {
      try {
         my $v = $params->( $k, { optional => TRUE } );

         $stash->{prefs}->{ $k } = defined $v ? $sess->$k( $v ) : $sess->$k();
      }
      catch { $self->log->warn( $_ ) };
   }

   $stash->{skin} = delete $stash->{prefs}->{skin};

   for my $k (@{ $conf->stash_attr->{links} }) {
      $stash->{links}->{ $k } = $req->uri_for( $conf->$k() );
   }

   $stash->{links}->{base_uri} = $req->base;
   $stash->{links}->{req_uri } = $req->uri;

   $stash->{scripts} = [ @{ $self->_js_files } ];

   return $stash;
};

around 'load_page' => sub {
   my ($orig, $self, $req, @args) = @_;

   my $page = $orig->( $self, $req, @args ); my $conf = $self->config;

   for my $k (@{ $conf->stash_attr->{request} }) { $page->{ $k }   = $req->$k  }

   for my $k (@{ $conf->stash_attr->{config } }) { $page->{ $k } //= $conf->$k }

   $page->{application_version} = $conf->appclass->VERSION;
   $page->{status_message     } = $req->session->collect_status_message( $req );

   $page->{hint  } //= $req->loc( 'Hint' );
   $page->{locale} //= $req->locale;

   return $page;
};

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
