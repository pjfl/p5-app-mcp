package App::MCP::Schema::Schedule::Result::HistoryList;

use App::MCP::Constants qw( EXCEPTION_CLASS FALSE TRUE );
use App::MCP::Util      qw( concise_duration foreign_key_data_type
                            nullable_varchar_data_type numerical_data_type
                            numerical_id_data_type varchar_data_type );
use DBIx::Class::Moo::ResultClass;

extends 'App::MCP::Schema::Base';

my $class  = __PACKAGE__;
my $result = 'App::MCP::Schema::Schedule::Result';

$class->table_class('DBIx::Class::ResultSource::View');

$class->table('history_list');

$class->result_source_instance->is_virtual(TRUE);

$class->result_source_instance->view_definition(qq{
   select crosstab.job_id, crosstab.runid, crosstab.pid, crosstab.rv,
      crosstab.rejected, crosstab.start as started,
      coalesce(crosstab.finish, crosstab.terminate, crosstab.fail) as finished,
      coalesce(crosstab.terminate, crosstab.fail) as failed
   from crosstab('
      select runid, job_id, pid, rv, rejected, transition, created
      from processed_events
      where length(runid) != 0
      order by runid, created desc','
      select distinct transition
      from processed_events
      where transition in (''fail'', ''finish'', ''start'', ''terminate'')
      order by transition'
   ) crosstab(
      runid varchar(20) collate "C",
      job_id integer,
      pid integer,
      rv integer,
      rejected text,
      fail timestamp,
      finish timestamp,
      start timestamp,
      terminate timestamp
   )
});

$class->add_columns(
   job_id   => foreign_key_data_type,
   runid    => varchar_data_type(20),
   pid      => numerical_data_type,
   rv       => numerical_id_data_type,
   rejected => nullable_varchar_data_type(16),
   started  => { data_type => 'timestamp', timezone => 'UTC' },
   finished => { data_type => 'timestamp', timezone => 'UTC' },
   failed   => { data_type => 'timestamp', timezone => 'UTC' },
);

$class->belongs_to(job => "${result}::Job", 'job_id');

sub duration {
   my $self = shift;

   return unless $self->finished && $self->started;

   return concise_duration($self->finished->epoch - $self->started->epoch);
}

sub success {
   my $self = shift;

   return FALSE if $self->rejected || $self->failed;

   return unless $self->finished;

   return $self->rv <= $self->job->expected_rv ? TRUE : FALSE;
}

use namespace::autoclean;

1;
