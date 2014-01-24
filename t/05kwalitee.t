# @(#)Ident: 05kwalitee.t 2013-08-21 20:42 pjf ;

use strict;
use warnings;
use File::Spec::Functions qw( catdir updir );
use FindBin               qw( $Bin );
use lib               catdir( $Bin, updir, 'lib' );

use English qw(-no_match_vars);
use Test::More;

BEGIN {
   $ENV{AUTHOR_TESTING} or plan skip_all => 'Kwalitee test only for developers';
}

eval { require Test::Kwalitee; };

$EVAL_ERROR and plan skip_all => 'Test::Kwalitee not installed';

# Since we now use a custom Moose exporter this metric is no longer valid
Test::Kwalitee->import( tests => [ qw(-use_strict) ] );

unlink q(Debian_CPANTS.txt);

# Local Variables:
# mode: perl
# tab-width: 3
# End:
