package App::MCP::Model::History;

use App::MCP::Constants    qw( EXCEPTION_CLASS FALSE TRUE );
use App::MCP::Util         qw( redirect );
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
   my ($self, $context, $jobid) = @_;

   my $job = $context->model('Job')->find_by_key($jobid);

   return $self->error($context, UnknownJob, [$jobid]) unless $job;

   $context->stash(job => $job);

   my $nav = $context->stash('nav')->list('history');

   $nav->item('history/view', [$job->id])->item('history/runlist', [$job->id]);
   return;
}

sub runid : Auth('view') Capture(1) {
   my ($self, $context, $runid) = @_;

   $context->stash(runid => $runid);

   my $jobid = $context->stash('job')->id;
   my $nav   = $context->stash('nav');

   $nav->list('history')->item('history/runview', [$jobid, $runid]);
   return;
}

sub list : Auth('view') Nav('History|img/history.svg') {
   my ($self, $context) = @_;

   my $options = { context => $context };

   if (my $job = $context->stash('job')) {
      $options->{caption} = 'List Job Runs';
      $options->{job} = $job;
   }

   $context->stash(
      page  => { layout => 'history/list' },
      table => $self->new_table('History', $options),
   );
   $context->stash('nav')->finalise;
   return;
}

sub runlist : Auth('view') Nav('Job Runs') {
   my ($self, $context) = @_; return $self->list($context);
}

sub runview : Auth('view') Nav('Run History') {
   my ($self, $context) = @_; return $self->view($context);
}

sub view : Auth('view') Nav('Job Events') {
   my ($self, $context) = @_;

   my $job = $context->stash('job');

   return $self->error($context, Unspecified, ['job']) unless $job;

   my $options = { context => $context, job => $job };

   if (my $runid = $context->stash('runid')) {
      $options->{caption} = 'View Run History';
      $options->{runid} = $runid;
   }

   $context->stash(
      page  => { layout => 'history/view' },
      table => $self->new_table('View::History', $options),
   );
   $context->stash('nav')->finalise;
   return;
}

1;
