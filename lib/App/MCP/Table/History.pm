package App::MCP::Table::History;

use HTML::StateTable::Constants qw( FALSE NUL SPC TABLE_META TRUE );
use Moo;
use HTML::StateTable::Moo;

extends 'HTML::StateTable';
with    'HTML::StateTable::Role::Configurable';

has '+caption' => default => 'Job History List';

has '+configurable_action' => default => 'api/table_preference';

has '+configurable_control_location' => default => 'TopRight';

has '+icons' => default => sub { shift->context->icons_uri->as_string };

has '+page_control_location' => default => 'TopLeft';

has '+page_size_control_location' => default => 'BottomLeft';

has 'job' => is => 'ro', predicate => 'has_job';

set_table_name 'history';

setup_resultset sub {
   my $self  = shift;
   my $rs    = $self->context->model('HistoryList');
   my $where = $self->has_job ? { job_id => $self->job->id } : {};

   return $rs->search($where, { prefetch => 'job' });
};

has_column 'job_name' =>
   label    => 'Job Name',
   sortable => TRUE,
   title    => 'Sort by job',
   value    => 'job.job_name',
   link     => sub {
      my $self    = shift;
      my $context = $self->table->context;

      return $context->uri_for_action('history/view', [$self->result->job_id]);
   };

has_column 'runid' =>
   label    => 'Run ID',
   sortable => TRUE,
   link     => sub {
      my $self    = shift;
      my $context = $self->table->context;
      my $args    = [$self->result->job_id, $self->result->runid];

      return $context->uri_for_action('history/view', $args);
   };

has_column 'started' => cell_traits => ['DateTime'];

has_column 'finished' => cell_traits => ['DateTime'];

has_column 'duration';

has_column 'success' => cell_traits => ['Bool'];

use namespace::autoclean -except => TABLE_META;

1;
