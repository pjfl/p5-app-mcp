package App::MCP::Table::View::History;

use HTML::StateTable::Constants qw( FALSE NUL SPC TABLE_META TRUE );
use Moo;
use HTML::StateTable::Moo;

extends 'HTML::StateTable';

has '+caption' => default => 'Job History View';

has '+icons' => default => sub { shift->context->icons_uri->as_string };

has '+page_control_location' => default => 'TopLeft';

has '+page_size_control_location' => default => 'BottomLeft';

has 'job' => is => 'ro', required => TRUE;

has 'runid' => is => 'ro', predicate => 'has_runid';

set_table_name 'history_view';

setup_resultset sub {
   my $self  = shift;
   my $rs    = $self->context->model('ProcessedEvent');
   my $where = {};

   if ($self->has_runid) { $where = { runid => $self->runid } }
   else { $where = { job_id => $self->job->id } }

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

      return $context->uri_for_action('history/runview', $args);
   };

has_column 'created' => cell_traits => ['DateTime'], sortable => TRUE;

has_column 'processed' => cell_traits => ['DateTime'], sortable => TRUE;

has_column 'transition' => sortable => TRUE;

has_column 'rejected' => sortable => TRUE;

has_column 'pid' => cell_traits => ['Numeric'], label => 'PID';

has_column 'rv' => cell_traits => ['Numeric'], label => 'RV';

use namespace::autoclean -except => TABLE_META;

1;
