use strict;
use warnings;
use File::Spec::Functions qw( catdir updir );
use FindBin               qw( $Bin );
use lib               catdir( $Bin, updir, 'lib' );

use English qw(-no_match_vars);
use Test::More;

BEGIN {
   $ENV{AUTHOR_TESTING}
      or plan skip_all => 'POD coverage test only for developers';
}

eval "use Test::Pod::Coverage 1.04";

$EVAL_ERROR and plan skip_all => 'Test::Pod::Coverage 1.04 required';

all_pod_coverage_ok();

# Local Variables:
# mode: perl
# tab-width: 3
# End:
