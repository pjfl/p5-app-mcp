# @(#)$Ident: 11job.t 2013-08-21 20:43 pjf ;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.3.%d', q$Rev: 1 $ =~ /\d+/gmx );
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

use_ok 'App::MCP::Schema';

my $factory = App::MCP::Schema->new( appclass => 'App::MCP', nodebug => 1 );
my $schema  = $factory->schedule;

# Job
my $rs = $schema->resultset( 'Job' ); my $job;

$job = $rs->search( { fqjn => 'main::test' } )->first;

$job and $job->delete; # Left over job and event from previous run

eval { $job = $rs->create( {} ) }; my $e = $@; $@ = undef;

like $e, qr{ Validation \s+ errors }msx, 'Validation errors';

like $e && $e->args->[ 0 ], qr{ eMandatory }msx, 'Job name mandatory';

$job and $job->in_storage and $job->delete; $job = undef;

eval { $job = $rs->create( { name => '~' } ) }; $e = $@; $@ = undef;

like $e && $e->args->[ 0 ], qr{ eSimpleText }msx,
   'Job name must be simple text';

$job and $job->delete; $job = undef;

eval { $job = $rs->create( { name => 'x' x 127 } ) }; $e = $@; $@ = undef;

like $e && $e->args->[ 0 ], qr{ eValidLength }msx,
   'Job name must be less than 127 characters';

$job and $job->delete; $job = undef;

$job = $rs->create( { command => 'sleep 1', name => 'test',
                      type    => 'job',     user => 'mcp' } );

ok $job->id > 0, 'Creates a job';

is $job->fqjn, 'main::test', 'Sets fully qualified job name';

my $job1 = $rs->search( { fqjn => 'main::test1' } )->first;

$job1 and $job1->delete; # Left over job and event from previous run

$job1 = $rs->create( { condition => 'finished( test )',
                       command   => 'sleep 1', name => 'test1',
                       type      => 'job',     user => 'mcp' } );

is $job1->fqjn, 'main::test1', 'Creates job with condition';

my $job2 = $rs->search( { fqjn => 'main::test2' } )->first;

$job2 and $job2->delete; # Left over job and event from previous run

my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = gmtime;

$job2 = $rs->create( { crontab => ($min + 1).' '.$hour.' * * *',
                       command => 'sleep 1', name => 'test2',
                       type    => 'job',     user => 'mcp' } );

is $job2->fqjn, 'main::test2', 'Creates job with crontab';

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
