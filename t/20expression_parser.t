use t::boilerplate;

use Test::More;

use_ok 'App::MCP::ExpressionParser';

my $ep = App::MCP::ExpressionParser->new
   ( { external   => Dummy->new,
       predicates => [ qw( finished running terminated ) ] } );

my $r = $ep->parse( 'running( test_job ) & ! finished( test_job1 )' );

is $r->[ 0 ], 0, 'T1';

$r = $ep->parse( 'running( test_job ) & ! finished( test_job )' );

is $r->[ 0 ], 1, 'T2';

$r = $ep->parse( '! running( test_job1 ) & terminated( test_job2 )' );

is $r->[ 0 ], 1, 'T3';

$r = $ep->parse( '!! running( test_job1 ) & terminated( test_job2 )' );

is $r->[ 0 ], 0, 'T4';

$r = $ep->parse( '! running( test_job ) | finished( test_job1 )' );

is $r->[ 0 ], 1, 'T5';

$r = $ep->parse( '! running( test_job ) | ! finished( test_job1 )' );

is $r->[ 0 ], 0, 'T6';

$r = $ep->parse( 'running( test_job ) & finished( test_job1 ) & terminated( test_job2 )' );

is $r->[ 0 ], 1, 'T7';

is( (join ' ', sort @{ $r->[ 1 ] }), 'test_job test_job1 test_job2',
    'Job list' );

done_testing;

{  package Dummy;

   sub new {
      return bless {}, 'Dummy';
   }

   sub finished {
      return $_[ 1 ] eq 'test_job' ? 0 : 1;
   }

   sub running {
      return $_[ 1 ] eq 'test_job' ? 1 : 0;
   }

   sub terminated {
      return $_[ 1 ] eq 'test_job2' ? 1 : 0;
   }

   1;
}

# Local Variables:
# mode: perl
# tab-width: 3
# End:
