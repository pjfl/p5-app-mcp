package App::MCP::Controller::Forms;

use namespace::sweep;

use Web::Simple;

sub dispatch_request {
   sub (POST + (/job/* | /job) + ?*) {
      return shift->execute( qw( html job from_request ), @_ );
   },
   sub (GET  + (/job/* | /job) + ?*) {
      return shift->execute( qw( html job definition_form ), @_ );
   },
   sub (GET  + /job_chooser + ?*) {
      return shift->execute( qw( xml  job chooser ), @_ );
   },
   sub (GET  + /job_grid_rows + ?*) {
      return shift->execute( qw( xml  job grid_rows ), @_ );
   },
   sub (GET  + /job_grid_table + ?*) {
      return shift->execute( qw( xml  job grid_table ), @_ );
   },
   sub (GET  + /job_state/* + ?*) {
      return shift->execute( qw( xml  job job_state ), @_ );
   },
   sub (GET  + /state_diagram) {
      return shift->execute( qw( html state diagram ), @_ );
   };
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
