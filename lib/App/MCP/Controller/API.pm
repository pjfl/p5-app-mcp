package App::MCP::Controller::API;

use Web::Simple;

with q(App::MCP::Role::Component);

has '+moniker' => default => 'api';

sub dispatch_request {
   sub (POST + /api/authenticate/*     ) { [ 'api', 'authenticate',      @_ ] },
   sub (GET  + /api/authenticate/* + ?*) { [ 'api', 'exchange_pub_keys', @_ ] },
   sub (POST + /api/event          + ?*) { [ 'api', 'create_event',      @_ ] },
   sub (POST + /api/job            + ?*) { [ 'api', 'create_job',        @_ ] },
   sub (GET  + /api/state          + ?*) { [ 'api', 'snapshot_state',    @_ ] };
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
