use t::boilerplate;

use Test::More;

use_ok 'App::MCP::Schema';

my $factory = App::MCP::Schema->new( appclass => 'App::MCP', noask => 1 );
my $schema  = $factory->schema;

# Job
my $rs = $schema->resultset( 'Job' );
my $job;

$job = $rs->search( { job_name => 'DevSched' } )->single;

$job->delete if $job; # Left over job and event from previous run

eval { $job = $rs->create( {} ) }; my $e = $@; $@ = undef;

like $e, qr{ \Qvalidation error\E }msx, 'Validation errors';

like $e && $e->args->[ 0 ], qr{ mandatory }msx, 'Job name mandatory';

$job->delete if $job && $job->in_storage;
$job = undef;

eval { $job = $rs->create( { job_name => '~' } ) }; $e = $@; $@ = undef;

like $e && $e->args->[ 0 ], qr{ \Qdoes not match\E }msx,
   'Job name must be simple text';

$job->delete if $job;
$job = undef;

eval { $job = $rs->create( { job_name => 'x' x 256 } ) }; $e = $@; $@ = undef;

like $e && $e->args->[ 0 ], qr{ \Qhas an invalid length\E }msx,
   'Job name must be less than 255 characters';

$job->delete if $job;
$job = undef;

$job = $rs->create({ job_name => 'DevSched', type => 'box', user_name => 'mcp' });

ok $job->id > 0, 'Creates a box';
is $job->job_name, 'DevSched', 'Sets fully qualified job name';

$job = $rs->create( { job_name => 'Batch', parent_name => 'DevSched',
                      type => 'box', user_name => 'mcp', owner_id => 1 } );

is $job->job_name, 'DevSched/Batch', 'Non root parent';

$job = $rs->create( { job_name => 'Overnight', parent_name => 'DevSched/Batch',
                      type => 'box', user_name => 'mcp', owner_id => 1} );

is $job->job_name, 'DevSched/Overnight', 'Non root parent - 2';

$job = $rs->create( { command     => 'sleep 1',
                      job_name    => 'EOD',
                      owner_id    => 1,
                      parent_name => 'DevSched/Overnight',
                      type        => 'job',
                      user_name   => 'mcp' } );

is $job->job_name, 'DevSched/Overnight/EOD', 'Creates job';

$job = $rs->create( { condition   => 'finished( EOD )',
                      command     => 'sleep 1',
                      job_name    => 'SOB',
                      owner_id    => 1,
                      parent_name => 'DevSched/Overnight',
                      type        => 'job',
                      user_name   => 'mcp' } );

is $job->job_name, 'DevSched/Overnight/SOB', 'Creates job with condition';

$job = $rs->create( { condition   => 'finished( SOB )',
                      command     => '/bin/sleep 2',
                      job_name    => 'Remote1',
                      owner_id    => 1,
                      parent_name => 'DevSched/Overnight',
                      type        => 'job',
                      user_name   => 'mcp', } );

$job = $rs->create( { job_name => 'Cron', parent_name => 'DevSched',
                      type => 'box', user_name=> 'mcp', owner_id => 1 } );

is $job->job_name, 'DevSched/Cron', 'Non root parent - 3';

my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = gmtime;

$job = $rs->create( { crontab     => ($min + 1).' '.$hour.' * * *',
                      command     => 'sleep 1',
                      job_name    => 'Timed1',
                      owner_id    => 1,
                      parent_name => 'DevSched/Cron',
                      type        => 'job',
                      user_name   => 'mcp' } );

is $job->job_name, 'DevSched/Cron/Timed1', 'Creates job with crontab';

$job = $rs->find_by_key('TestSched');
$job->delete if $job;

$job = $rs->create({
   owner_id  => 1,
   job_name  => 'TestSched',
   type      => 'box',
   user_name => 'mcp'
});

ok $job->id > 0, 'Creates test schedule container';

$job = $rs->find_by_key('DevSched');
$job->delete if $job;

$job = $rs->find_by_key('TestSched');
$job->delete if $job;

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
