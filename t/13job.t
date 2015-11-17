use t::boilerplate;

use Test::More;

use_ok 'App::MCP::Schema';

my $factory = App::MCP::Schema->new( appclass => 'App::MCP', noask => 1 );
my $schema  = $factory->schedule;

# Job
my $rs = $schema->resultset( 'Job' ); my $job;

$job = $rs->search( { name => 'DevSched' } )->first;

$job and $job->delete; # Left over job and event from previous run

eval { $job = $rs->create( {} ) }; my $e = $@; $@ = undef;

like $e, qr{ \Qvalidation error\E }msx, 'Validation errors';

like $e && $e->args->[ 0 ], qr{ mandatory }msx, 'Job name mandatory';

$job and $job->in_storage and $job->delete; $job = undef;

eval { $job = $rs->create( { name => '~' } ) }; $e = $@; $@ = undef;

like $e && $e->args->[ 0 ], qr{ \Qdoes not match\E }msx,
   'Job name must be simple text';

$job and $job->delete; $job = undef;

eval { $job = $rs->create( { name => 'x' x 256 } ) }; $e = $@; $@ = undef;

like $e && $e->args->[ 0 ], qr{ \Qnot a valid length\E }msx,
   'Job name must be less than 255 characters';

$job and $job->delete; $job = undef;

$job = $rs->create( { name => 'DevSched', type => 'box', user => 'mcp' } );

ok $job->id > 0, 'Creates a box';
is $job->name, 'DevSched', 'Sets fully qualified job name';

$job = $rs->create( { name => 'Batch', parent_name => 'DevSched',
                      type => 'box',   user        => 'mcp' } );

is $job->name, 'DevSched/Batch', 'Non root parent';

$job = $rs->create( { name => 'Overnight', parent_name => 'DevSched/Batch',
                      type => 'box',       user        => 'mcp' } );

is $job->name, 'DevSched/Overnight', 'Non root parent - 2';

$job = $rs->create( { command     => 'sleep 1',
                      name        => 'EOD',
                      parent_name => 'DevSched/Overnight',
                      type        => 'job',
                      user        => 'mcp' } );

is $job->name, 'DevSched/Overnight/EOD', 'Creates job';

$job = $rs->create( { condition   => 'finished( EOD )',
                      command     => 'sleep 1',
                      name        => 'SOB',
                      parent_name => 'DevSched/Overnight',
                      type        => 'job',
                      user        => 'mcp' } );

is $job->name, 'DevSched/Overnight/SOB', 'Creates job with condition';

$job = $rs->create( { condition   => 'finished( SOB )',
                      command     => '/bin/sleep 2',
                      host        => 'head',
                      name        => 'Remote1',
                      parent_name => 'DevSched/Overnight',
                      type        => 'job',
                      user        => 'mcp', } );

$job = $rs->create( { name => 'Cron', parent_name => 'DevSched',
                      type => 'box',  user        => 'mcp' } );

is $job->name, 'DevSched/Cron', 'Non root parent - 3';

my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = gmtime;

$job = $rs->create( { crontab     => ($min + 1).' '.$hour.' * * *',
                      command     => 'sleep 1',
                      name        => 'Timed1',
                      parent_name => 'DevSched/Cron',
                      type        => 'job',
                      user        => 'mcp' } );

is $job->name, 'DevSched/Cron/Timed1', 'Creates job with crontab';

$job = $rs->create( { name => 'TestSched', type => 'box', user => 'mcp' } );

ok $job->id > 0, 'Creates test schedule container';

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
