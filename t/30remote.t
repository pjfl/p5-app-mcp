use strict;
use warnings;
use File::Spec::Functions qw( catdir updir );
use FindBin               qw( $Bin );
use lib               catdir( $Bin, updir, 'lib' );

use Test::More;
use Test::Requires { version => 0.88 };
use Module::Build;

my $notes = {}; my $perl_ver;

BEGIN {
   my $builder = eval { Module::Build->current };
      $builder and $notes = $builder->notes;
      $perl_ver = $notes->{min_perl_version} || 5.008;
}

use Test::Requires "${perl_ver}";

use Class::Usul;
use App::MCP::Application;

my $usul  = Class::Usul->new
   ( config       => { appclass => 'App::MCP', tempdir => 't' },
     config_class => 'App::MCP::Config',
     debug        => 1, );
my $app   = App::MCP::Application->new( builder => $usul );
my $class = $usul->config->appclass;
my $args  = { appclass => $class, command => '/bin/ls 1>/tmp/fli 2>&1' };
my $calls = [ [ 'remote_env', [ $class ] ],
              [ 'dispatch',   [ $class, "${class}::Worker", %{ $args } ] ], ];

$app->_add_provisioning( $usul->config->appclass, $calls, 'mcp@head' );

my $res = $app->ipc_ssh_handler( 1, 'mcp', 'head', $calls );

is $res, 1, 'Remote provison';

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
