# @(#)$Id$

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );
use File::Spec::Functions;
use FindBin qw( $Bin );
use lib catdir( $Bin, updir, q(lib) );

use Module::Build;
use Test::More;

BEGIN {
   my $current = eval { Module::Build->current };

   $current and $current->notes->{stop_tests}
            and plan skip_all => $current->notes->{stop_tests};
}

use_ok 'App::MCP::Schema';

my $factory = App::MCP::Schema->new( appclass => 'App::MCP', nodebug => 1 );
my $schema  = $factory->schedule;
my $rs      = $schema->resultset( 'Job' );
my $job     = $rs->create( { name => 'test', type => 'box', user => 'mcp' } );
   $job     = $rs->find( $job->id );

is $job->fqjn, 'main::test', 'Sets fully qualified job name';

#$factory->dumper( { $job->get_inflated_columns } );

$job->delete;

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
