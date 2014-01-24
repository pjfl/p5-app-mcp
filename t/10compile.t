# @(#)$Ident: 10compile.t 2014-01-17 18:38 pjf ;

use strict;
use warnings;
use File::Spec::Functions qw( catdir updir );
use FindBin               qw( $Bin );
use lib               catdir( $Bin, updir, 'lib' );

use Module::Build;
use Test::More;

my $notes = {}; my $perl_ver;

BEGIN {
   my $builder = eval { Module::Build->current };
      $builder and $notes = $builder->notes;
      $perl_ver = $notes->{min_perl_version} || 5.008;
}

use Test::Requires "${perl_ver}";

use_ok 'App::MCP';
use_ok 'App::MCP::Functions';
use_ok 'App::MCP::Daemon';
use_ok 'App::MCP::Listener';
use_ok 'App::MCP::Schema';
use_ok 'App::MCP::Schema::Schedule';
use_ok 'App::MCP::View::HTML';

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
