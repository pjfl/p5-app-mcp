package App::MCP::Model::History;

use App::MCP::Constants    qw( EXCEPTION_CLASS FALSE TRUE );
use App::MCP::Util         qw( redirect redirect2referer );
use Unexpected::Functions  qw( UnknownJob Unspecified );
use Moo;
use App::MCP::Attributes;  # Will do cleaning

extends 'App::MCP::Model';
with    'Web::Components::Role';

has '+moniker' => default => 'history';

# Public methods
sub base : Auth('view') {
   my ($self, $context) = @_;

   $context->stash('nav')->list('history')->finalise;

   return;
}

sub jobid : Auth('view') Capture(1) {
   my ($self, $context, $jobid, $runid) = @_;

   my $job = $context->model('Job')->find_by_key($jobid);

   return $self->error($context, UnknownJob, [$jobid]) unless $job;

   $context->stash(job => $job);
   $context->stash('nav')->list('history')->item('history/view', [$job->id]);
   return;
}

sub runid : Auth('view') Capture(1) {
   my ($self, $context, $runid) = @_;

   $context->stash(runid => $runid);

   my $args = [$context->stash('job')->id, $runid];
   my $nav  = $context->stash('nav')->list('history');

   $nav->item('history/runview', $args)->finalise;
   return;
}

sub joblist : Auth('view') {
   my ($self, $context) = @_; return $self->list($context);
}

sub list : Auth('view') Nav('History|img/history.svg') {
   my ($self, $context) = @_;

   my $options = { context => $context };
   my $job     = $context->stash('job');

   $options->{job} = $job if $job;

   $context->stash(
      page  => { layout => 'history/list' },
      table => $self->new_table('History', $options),
   );
   $context->stash('nav')->finalise;
   return;
}

sub runview : Auth('view') Nav('Run History') {
   my ($self, $context) = @_; return $self->view($context);
}

sub view : Auth('view') Nav('Job History') {
   my ($self, $context) = @_;

   my $job = $context->stash('job');

   return $self->error($context, Unspecified, ['job']) unless $job;

   my $options = { context => $context, job => $job };

   if (my $runid = $context->stash('runid')) {
      $options->{caption} = 'Run History View';
      $options->{runid} = $runid;
   }
   else { $context->stash('nav')->finalise }

   $context->stash(
      page  => { layout => 'history/view' },
      table => $self->new_table('View::History', $options),
   );
   return;
}

1;
