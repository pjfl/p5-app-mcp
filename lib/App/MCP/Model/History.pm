package App::MCP::Model::History;

use App::MCP::Constants    qw( EXCEPTION_CLASS FALSE TRUE );
use App::MCP::Util         qw( redirect redirect2referer );
use Unexpected::Functions  qw( UnknownJob );
use Moo;
use App::MCP::Attributes;  # Will do cleaning

extends 'App::MCP::Model';
with    'Web::Components::Role';

has '+moniker' => default => 'history';

# Public methods
sub base : Auth('view') {
   my ($self, $context, $jobid, $runid) = @_;

   my $nav = $context->stash('nav')->list('history');

   if ($jobid) {
      my $job = $context->model('Job')->find_by_key($jobid);

      return $self->error($context, UnknownJob, [$jobid]) unless $job;

      $context->stash(job => $job);
   }

   $nav->finalise;
   return;
}

sub list : Auth('view') Nav('History') {
   my ($self, $context) = @_;

   my $options = { context => $context };
   my $job     = $context->stash->{job};

   $options->{job} = $job if $job;

   $context->stash(table => $self->new_table('History', $options));
   return;
}

sub view : Auth('view') Nav('View History') {
   my ($self, $context, $runid) = @_;

   my $options = { context => $context, result => $context->stash('job') };

   $context->stash(table => $self->new_table('History::View', $options));
   return;
}

1;
