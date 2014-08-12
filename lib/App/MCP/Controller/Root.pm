package App::MCP::Controller::Root;

use Web::Simple;

with q(App::MCP::Role::Component);

has '+moniker' => default => 'root';

sub dispatch_request {
   sub (GET  + /check_field      + ?*) { [ 'root', 'check_field',  @_ ] },
   sub (POST + /login/* | /login + ?*) { [ 'root', 'from_request', @_ ] },
   sub (GET  + /login/* | /login + ?*) { [ 'root', 'login_form',   @_ ] },
   sub (POST + /logout               ) { [ 'root', 'logout',       @_ ] },
   sub (GET  + /nav_list             ) { [ 'root', 'nav_list',     @_ ] },
   sub ()                              { [ 'root', 'not_found',    @_ ] };
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
