use t::boilerplate;

use Test::More;

use_ok 'App::MCP';
use_ok 'App::MCP::Functions';
use_ok 'App::MCP::Daemon';
use_ok 'App::MCP::Listener';
use_ok 'App::MCP::Model::API';
use_ok 'App::MCP::Schema';
use_ok 'App::MCP::Schema::Schedule';
use_ok 'App::MCP::View::HTML';
use_ok 'App::MCP::Async::Process';
use_ok 'App::MCP::Async::Function';
use_ok 'App::MCP::Async::Routine';

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
