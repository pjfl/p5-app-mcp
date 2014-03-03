package App::MCP::Controller::API;

use namespace::sweep;

use Web::Simple;

sub dispatch_request {
   sub (GET  + /api/authenticate/* + ?*) {
      return shift->execute( qw( json api exchange_pub_keys ), @_ );
   },
   sub (POST + /api/authenticate/*) {
      return shift->execute( qw( json api authenticate ), @_ );
   },
   sub (POST + /api/event + ?*) {
      return shift->execute( qw( json api create_event ), @_ );
   },
   sub (POST + /api/job + ?*) {
      return shift->execute( qw( json api create_job ), @_ );
   },
   sub (GET  + /api/state + ?*) {
      return shift->execute( qw( json api snapshot_state ), @_ );
   };
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
