# @(#)$Ident: 15event.t 2013-06-02 14:54 pjf ;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.2.%d', q$Rev: 19 $ =~ /\d+/gmx );
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
my $job_rs  = $schema->resultset( 'Job' );
my $jobs    = $job_rs->search( { fqjn => 'main::test' } );
my $job     = $jobs->first;

# Event

my $rs = $schema->resultset( 'Event' ); my $event;

eval { $event = $rs->create( {} ) }; my $e = $@; $@ = undef;

like $e && $e->args->[ 0 ], qr{ eMandatory }msx, 'Event name mandatory';

$event and $event->delete; $event = undef;

eval { $event = $rs->create( { job_id => $job->id } ) }; $e = $@; $@ = undef;

like $e && $e->args->[ 0 ], qr{ eMandatory }msx, 'Event transition mandatory';

$event and $event->delete; $event = undef;

eval { $event = $rs->create( { job_id => $job->id, transition => 'start' } ) };

$e = $@; $@ = undef;

$e and unlike $e, qr{ validation \s+ errors }imsx, 'Event validation errors';

if ($e) { warn $_.' '.$_->args->[ 0 ] for (@{ $e->args }) }

$event and is $event->job_id, $job->id, 'Creates a start event';

#$e and warn "$e\n";

#$job and $factory->dumper( { $job->get_inflated_columns } );

#$event and $event->delete; $event = undef;

#$job->delete;

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
