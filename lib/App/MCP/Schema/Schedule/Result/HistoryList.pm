package App::MCP::Schema::Schedule::Result::HistoryList;

use App::MCP::Constants qw( EXCEPTION_CLASS FALSE TRUE );
use App::MCP::Util      qw( foreign_key_data_type varchar_data_type );
use DBIx::Class::Moo::ResultClass;

extends 'App::MCP::Schema::Base';

my $class  = __PACKAGE__;
my $result = 'App::MCP::Schema::Schedule::Result';

$class->table_class('DBIx::Class::ResultSource::View');

$class->table('history_list');

$class->result_source_instance->is_virtual(TRUE);

$class->result_source_instance->view_definition(qq{
   select * from crosstab('
      select runid, job_id, transition, created
      from processed_events
      where runid is not null
      order by 1','
      select distinct transition
      from processed_events
      where transition = ''start'' or transition = ''finish''
      order by 1'
   ) as processed_events(
      runid text,
      job_id integer,
      finish timestamp,
      start timestamp
   )
});

$class->add_columns(
   job_id => foreign_key_data_type,
   runid  => varchar_data_type( 20 ),
   start  => { data_type => 'timestamp' },
   finish => { data_type => 'timestamp' },
);

$class->belongs_to(job => "${result}::Job", 'job_id');

use namespace::autoclean;

1;
