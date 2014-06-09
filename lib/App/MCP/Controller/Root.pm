package App::MCP::Controller::Root;

use namespace::sweep;

use Web::Simple;

sub dispatch_request {
   sub (GET  + /check_field + ?*) {
      return shift->execute( qw( xml  root check_field ), @_ );
   },
   sub (POST + (/login/* | /login) + ?*) {
      return shift->execute( qw( html root from_request ), @_ );
   },
   sub (GET  + (/login/* | /login) + ?*) {
      return shift->execute( qw( html root login_form ), @_ );
   },
   sub (POST + /logout) {
      return shift->execute( qw( html root logout ), @_ );
   },
   sub (GET  + /nav_list) {
      return shift->execute( qw( xml  root nav_list ), @_ );
   },
   sub () {
      return shift->execute( qw( html root not_found ), @_ );
   };
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
