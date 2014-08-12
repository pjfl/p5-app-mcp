package App::MCP::Controller::Forms;

use Web::Simple;

with q(App::MCP::Role::Component);

has '+moniker' => default => 'forms';

sub dispatch_request {
   sub (POST + /job/* | /job   + ?*) { [ 'job',   'from_request',    @_ ] },
   sub (GET  + /job/* | /job   + ?*) { [ 'job',   'definition_form', @_ ] },
   sub (GET  + /job_chooser    + ?*) { [ 'job',   'chooser',         @_ ] },
   sub (GET  + /job_grid_rows  + ?*) { [ 'job',   'grid_rows',       @_ ] },
   sub (GET  + /job_grid_table + ?*) { [ 'job',   'grid_table',      @_ ] },
   sub (GET  + /job_state/*    + ?*) { [ 'job',   'job_state',       @_ ] },
   sub (GET  + /state_diagram      ) { [ 'state', 'diagram',         @_ ] };
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
