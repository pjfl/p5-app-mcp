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

# Event

$rs = $schema->resultset( 'Event' ); my $event;

eval { $event = $rs->create( {} ) }; $e = $@; $@ = undef;

like $e && $e->args->[ 0 ], qr{ eMandatory }msx, 'Event name mandatory';

$event and $event->delete; $event = undef;

eval { $event = $rs->create( { job_id => $job->id } ) }; $e = $@; $@ = undef;

like $e && $e->args->[ 0 ], qr{ eMandatory }msx, 'Event state mandatory';

$event and $event->delete; $event = undef;

eval { $event = $rs->create( { job_id => $job->id, state => 'starting' } ) };

$e = $@; $@ = undef;

like $e && $e->args->[ 0 ], qr{ eMandatory }msx, 'Event type mandatory';

$event and $event->delete; $event = undef;

eval { $event = $rs->create( { job_id => $job->id,
                               state  => 'starting',
                               type   => 'job_start' } ) };

$e = $@; $@ = undef;

$event and is $event->job_id, $job->id, 'Creates an event';

#$e and warn "$e\n";

#$job and $factory->dumper( { $job->get_inflated_columns } );

#$event and $event->delete; $event = undef;

#$job->delete;

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
