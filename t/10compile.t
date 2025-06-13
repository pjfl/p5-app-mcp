use t::boilerplate;

use Test::More tests => 8;

use_ok 'App::MCP';
use_ok 'App::MCP::Util';
use_ok 'App::MCP::Daemon';
use_ok 'App::MCP::Listener';
use_ok 'App::MCP::Model::API';
use_ok 'App::MCP::Schema';
use_ok 'App::MCP::Schema::Schedule';
use_ok 'App::MCP::View::HTML';

wait;

exit 0;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
