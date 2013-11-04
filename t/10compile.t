# @(#)$Ident: 10compile.t 2013-11-04 17:44 pjf ;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.3.%d', q$Rev: 8 $ =~ /\d+/gmx );
use File::Spec::Functions   qw( catdir updir );
use FindBin                 qw( $Bin );
use lib                 catdir( $Bin, updir, 'lib' );

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

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
