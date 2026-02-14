package App::MCP::Model::Logfile;

use HTML::StateTable::Constants qw( EXCEPTION_CLASS FALSE TRUE );
use App::MCP::Util              qw( redirect2referer );
use Unexpected::Functions       qw( Unspecified NotFound );
use Format::Human::Bytes;
use Moo;
use App::MCP::Attributes; # Will do namespace cleaning

extends 'App::MCP::Model';
with    'Web::Components::Role';
with    'App::MCP::Role::Redis';

has '+moniker' => default => 'logfile';

has '+redis_client_name' => default => 'logfile_cache';

has '_format_number' => is => 'ro', default => sub { Format::Human::Bytes->new};

sub base : Auth('admin') {
   my ($self, $context, $logfile) = @_;

   my $nav = $context->stash('nav')->list('logfile');

   $nav->item('logfile/view', [$logfile]) if $logfile;

   $nav->finalise;
   return;
}

sub clear_cache : Auth('admin') {
   my ($self, $context, $logfile) = @_;

   return unless $self->verify_form_post($context);

   return $self->error($context, Unspecified, ['logfile']) unless $logfile;

   my $path = $self->config->logsdir->catfile($logfile);

   return $self->error($context, NotFound, ["${path}"]) unless $path->exists;

   $self->redis_client->del($_) for ($self->redis_client->keys("${path}!*"));

   my $message = ['Cache cleared [_1]', "${path}"];

   $context->stash(redirect2referer $context, $message);
   return;
}

sub list : Auth('admin') Nav('Logfiles') {
   my ($self, $context) = @_;

   my $options = { context => $context };

   $context->stash(table => $self->new_table('Logfile', $options));
   return;
}

sub view : Auth('admin') Nav('View Logfile') {
   my ($self, $context, $logfile) = @_;

   return $self->error($context, Unspecified, ['logfile']) unless $logfile;

   my $path = $self->config->logsdir->catfile($logfile);

   return $self->error($context, NotFound, ["${path}"]) unless $path->exists;

   my $table_class = $self->_extension2table_class($path->extension);
   my $size        = $self->_format_number->base2($path->stat->{size});
   my $options     = {
      caption => "View ${logfile} (${size})",
      context => $context,
      path    => $path,
      redis   => $self->redis_client
   };

   $context->stash(table => $self->new_table($table_class, $options));
   return;
}

# Private methods
sub _extension2table_class {
   my ($self, $extension) = @_;

   return 'View::CSV' if $extension eq 'csv';

   return 'View::Apache';
}

1;
