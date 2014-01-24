# @(#)Ident: 02pod.t 2013-08-21 20:41 pjf ;

use strict;
use warnings;
use File::Spec::Functions qw( catdir updir );
use FindBin               qw( $Bin );
use lib               catdir( $Bin, updir, 'lib' );

use English qw(-no_match_vars);
use Test::More;

BEGIN {
   $ENV{AUTHOR_TESTING} or plan skip_all => 'POD test only for developers';
}

eval "use Test::Pod 1.14";

$EVAL_ERROR and plan skip_all => 'Test::Pod 1.14 required';

all_pod_files_ok();

# Local Variables:
# mode: perl
# tab-width: 3
# End:
