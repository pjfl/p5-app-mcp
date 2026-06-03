package App::MCP::Application;

use App::MCP::Constants    qw( COMMA FALSE NUL TRUE OK SPC TRANSITION_ENUM );
use Unexpected::Types      qw( ArrayRef LoadableClass NonEmptySimpleStr
                               NonZeroPositiveInt Object Str );
use App::MCP::Util         qw( concise_duration create_token distname
                               trigger_input_handler trigger_output_handler );
use Class::Usul::Cmd::Util qw( elapsed ensure_class_loaded includes );
use English                qw( -no_match_vars );
use HTML::Forms::Util      qw( json_bool );
use List::Util             qw( first );
use Scalar::Util           qw( weaken );
use Web::Components::Util  qw( fqdn );
use Web::ComposableRequest::Util
                           qw( bson64id );
use App::MCP::EventStream;
use App::MCP::Provisioning;
use IPC::PerlSSH;
use Try::Tiny;
use Moo;

=pod

=encoding utf8

=head1 Name

App::MCP::Application - Enterprise scheduling application

=head1 Synopsis

   use App::MCP::Application;

=head1 Description

Enterprise scheduling application

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=item C<builder>

Injected object dependency. Handles;

=over 3

=item C<config>

The L<configuration|App::MCP::Config> object

=item C<debug>

A boolean which if true turns on debug logging

=item C<log>

The L<logger|App::MCP::Log> object

=item C<port>

The port that the web server is listening on

=back

=cut

has 'builder' =>
   is       => 'ro',
   isa      => Object,
   handles  => [qw(config debug log port)],
   required => TRUE;

=item C<provisioner>

An instance of the L<remote provisioning|App::MCP::Provisioning> class

=cut

has 'provisioner' =>
   is      => 'lazy',
   default => sub {
      my $self = shift;
      my $args = { config => $self->config, log => $self->log };

      return App::MCP::Provisioning->new($args);
   };

=item C<servers>

A comma separated list of scheduling servers

=cut

has 'servers' =>
   is      => 'lazy',
   isa     => Str,
   default => sub { join COMMA, @{shift->config->servers} };

=item C<streamer>

An instance of the L<event stream|App::MCP::EventStream> class

=cut

has 'streamer' =>
   is      => 'lazy',
   default => sub {
      my $self = shift;
      my $args = { config => $self->config, log => $self->log };

      return App::MCP::EventStream->new($args);
   };

=item C<worker>

The L<worker|App::MCP::Worker> classname

=cut

has 'worker' =>
   is      => 'lazy',
   isa     => LoadableClass,
   coerce  => TRUE,
   default => sub { shift->config->appclass . '::Worker' };

# Private attributes
has '_input_transitions' =>
   is      => 'lazy',
   isa     => ArrayRef,
   default => sub {
      my $op_transitions = shift->_output_transitions;

      return [ grep { !includes $_, $op_transitions } @{TRANSITION_ENUM()} ];
   };

has '_output_transitions' =>
   is      => 'ro',
   isa     => ArrayRef,
   default => sub { ['force_start', 'kill_job', 'start'] };

with 'App::MCP::Role::JSONParser';
with 'App::MCP::Role::Redis';
with 'App::MCP::Role::Schema';

=back

=head1 Subroutines/Methods

Defines the following methods;

=over 3

=item C<BUILD>

Triggers contruction of the lazy C<streamer> attribute. Registers the event
callback plugins

=cut

sub BUILD {
   my $self = shift;

   $self->streamer->register_plugins;

   return;
}

=item C<availability_handler>

   $exit_code = $self->availability_handler($notifier_name, $daemon_pid);

=cut

sub availability_handler {
   my ($self, $name, $daemon_pid) = @_;

   return OK unless $self->config->enable_availability;

   my $host  = fqdn;
   my $token = $self->streamer->encode_access_token({ host => $host });

   for my $server (@{$self->config->servers}) {
      #next if $server eq $host;

      my $proto   = 'http';
      my $port    = $self->port;
      my $mount   = $self->config->mount_point;
      my $uri     = "${proto}://${server}:${port}${mount}/api/ping";
      my $res     = $self->streamer->http_get($uri, { token => $token });
      my $message = $res->{message};

      if ($res->{success}) {
         $self->log->info("${name}: Pong from ${message}");
      }
      else {
         # TODO: Do more
         $self->log->alert("${name}: " . $res->{error});
      }
   }

   return OK;
}

=item C<cron_job_handler>

   $exit_code = $self->cron_job_handler($notifier_name, $daemon_pid);

Creates start events for active jobs that should start now. Triggers the output
handler if any start events are created. Called at
C<config>.C<clock_tick_interval> seconds by the clock notifier

Returns zero

=cut

sub cron_job_handler {
   my ($self, $name, $daemon_pid) = @_;

   $self->_cron_log_interval($name);

   my $schema  = $self->schema;
   my $job_rs  = $schema->resultset('Job');
   my $ev_rs   = $schema->resultset('Event');
   my $trigger = FALSE;

   for my $job (grep { $_->should_start_now } $job_rs->active_crontab->all) {
      next if $job->condition && !$job->start_condition;

      $ev_rs->create({ job_id => $job->id, transition => 'start' });
      $trigger = TRUE;
   }

   trigger_output_handler $daemon_pid if $trigger;
   return OK;
}

=item C<event_stream_handler>

   $exit_code = $self->event_stream_handler($notifier_name, $daemon_pid);

Collects any accrued events since this method was last called. Posts/pushes
these events to any registered clients

Returns zero

=cut

sub event_stream_handler {
   my ($self, $name, $daemon_pid) = @_;

   my $cache = $self->redis_client;
   my @events;

   for my $key ($cache->keys('event_stream-*')) {
      my $event = $cache->get($key);

      $cache->del($key);

      next unless $event;

      try   { push @events, $self->json_parser->decode($event) }
      catch { $self->log->error("${name}.stream_handler: ${_}") };
   }

   return OK unless scalar @events;

   my $payload = { events => $self->json_parser->encode([@events]) };

   $self->streamer->send_to_subscribers($name, $payload);

   return OK;
}

=item C<input_handler>

   $exit_code = $self->input_handler($notifier_name, $daemon_pid);

Processes input events updating the targeted job state. When successfully
processed events are moved to the processed events collection

Returns zero

=cut

sub input_handler {
   my ($self, $name, $daemon_pid) = @_;

   my $schema   = $self->schema;
   my $prefetch = { 'job' => 'state' };
   my $where    = { transition => $self->_input_transitions };
   my $options  = { order_by => { -asc => 'me.id' }, prefetch => $prefetch };
   my $ev_rs    = $schema->resultset('Event');
   my $events   = $ev_rs->search($where, $options);
   my $pev_rs   = $schema->resultset('ProcessedEvent');
   my $trigger  = TRUE;

   while ($trigger) {
      $trigger = FALSE;

      for my $event ($events->all) {
         $schema->txn_do(sub {
            my $pev = $self->_process_event($name, $event);

            $trigger = TRUE unless $pev->{rejected};

            $pev_rs->create($pev);
            $event->delete;
            $self->_input_event_cleanup($name, $ev_rs, $event);
         });
      }

      trigger_output_handler $daemon_pid if $trigger;
      $events->reset;
   }

   trigger_output_handler $daemon_pid;
   return OK;
}

=item C<max_runtime_handler>

   $exit_code = $self->max_runtime_handler($name, $daemon_pid);

Terminate any running jobs that have exceeded their maximum run time

=cut

# TODO: Do not kill more than once
sub max_runtime_handler {
   my ($self, $name, $daemon_pid) = @_;

   my $ev_rs      = $self->schema->resultset('Event');
   my $js_rs      = $self->schema->resultset('JobState');
   my $options    = { prefetch => 'job' };
   my @job_states = $js_rs->search({ name => 'running' }, $options)->all;
   my $triggered  = FALSE;

   for my $job_state (@job_states) {
      my $job         = $job_state->job;
      my $max_runtime = $job->max_runtime or next;
      my $label       = $job->label;
      my $start_time  = $job_state->last_start;

      next if $start_time eq 'never';

      $start_time->set_time_zone($self->config->local_tz);

      next unless time > $start_time->epoch + $max_runtime;

      $ev_rs->create({ job_id => $job->id, transition => 'kill_job' });

      my $message = "Killing ${label} max. runtime exceeded";

      $self->log->alert("${name}: ${message}");
      $self->_alert_subscribers($name, $message);
      $triggered = TRUE;
   }

   trigger_output_handler $daemon_pid if $triggered;

   return OK;
}

=item C<output_handler>

   $exit_code = $self->output_handler($name, $daemon_pid, $ipc_ssh);

Processes output events updating the targeted job state. When successfully
processed events are moved to the processed events collection

Returns zero

=cut

sub output_handler {
   my ($self, $name, $daemon_pid, $ipc_ssh) = @_;

   my $schema  = $self->schema;
   my $options = { prefetch => { 'job' => 'state' } };
   my $where   = { transition => $self->_output_transitions };
   my $events  = $schema->resultset('Event')->search($where, $options);
   my $trigger = TRUE;

   while ($trigger) {
      $trigger = FALSE;

      for my $event ($events->all) {
         my $transition = $event->transition eq 'kill_job' ? 'kill' : 'start';
         my $method     = "_process_${transition}_event";
         my $code       = sub { $self->$method($name, $event, $ipc_ssh) };

         $schema->txn_do($code) or next;

         trigger_input_handler $daemon_pid if $event->job->type eq 'box';
         $trigger = TRUE;
      }

      $events->reset;
   }

   return OK;
}

=item C<ssh_caller>

   $hash_ref = $self->ssh_caller($notifier, $runid, \%options);

The keys of the C<options> hash reference are;

=over 3

=item C<calls>

An array references of tuples. Each tuple consists of;

=over 3

=item C<method>

=item C<args>

=item C<callback>

=back

=item C<host>

=item C<user>

=back

Returns false on failure and a hash reference of results from calling any
registered callbacks

=cut

sub ssh_caller {
   my ($self, $notifier, $runid, $args) = @_;

   my $name    = $notifier->name;
   my $leader  = "${name}[${runid}]";
   my @options = (Host => $args->{host}, User => $args->{user});
   my $file    = $self->_get_identity_file($args);

   push @options, 'SshOptions', ['-i', $file] if $file;

   my $ips    = IPC::PerlSSH->new(@options);
   my $failed = FALSE;

   try   { $ips->use_library($self->config->library_class) }
   catch {
      $self->log->error("${leader}: Use library - ${_}");
      $failed = TRUE;
   };

   return FALSE if $failed;

   my $results = {};

   while (defined (my $call = shift @{$args->{calls}})) {
      my $resp;

      try   { $resp = $ips->call($call->[0], @{$call->[1]}) }
      catch {
         $self->log->error("${leader}: Call failed - ${_}");
         $failed = TRUE;
      };

      return FALSE if $failed;

      $self->log->debug("${leader}: Call succeeded - ${resp}");

      if (my $cb = $call->[2]) {
         $self->provisioner->$cb($leader, $call, $args, $resp, $results);
      }
   }

   return $results;
}

=item C<ssh_callback>

   $self->ssh_calback($notifier, \@args?);

Called by the C<ipc_ssh> notifier after the C<ssh_caller> has returned it's
results

The C<args> array reference should contain;

=over 3

=item C<runid>

Combined with the notifier name this is used as a leader in the log C<info>
call

=item C<results>

This should be the hash reference returned by C<ssh_caller>. It should contain
a key C<provisioned> (another hash reference) containing C<key> and C<value>
attributes

This is used to registered the version number of the worker for a given
host/user pair

=back

=cut

sub ssh_callback {
   my ($self, $notifier, $args) = @_;

   my ($runid, $results) = @{$args // []};

   return unless $results;

   my $key  = $results->{provisioned}->{key};
   my $val  = $results->{provisioned}->{value};
   my $name = $notifier->name;

   $self->log->info("${name}[${runid}]: Provisioned ${key} ${val}")
      if $self->provisioner->remote_provisioned($key, $val);

   return;
}

# Private methods
sub _alert_subscribers {
   my ($self, $name, $message) = @_;

   my $true    = json_bool TRUE;
   my $options = { beep => $true, name => $name, status => 'alert' };
   my $payload = { message => $message, options => $options };

   $self->streamer->send_to_subscribers($name, $payload);
   return;
}

sub _cron_log_interval {
   my ($self, $name) = @_;

   my $log_int = $self->config->cron_log_interval or return;
   my $elapsed = elapsed;
   my $rem     = $elapsed % $log_int;
   my $spread  = $self->config->clock_tick_interval / 2;

   $self->log->info("${name}: Elapsed " . concise_duration($elapsed))
      if ($rem > $log_int - $spread or $rem < $spread);

   return;
}

sub _dispatch_args {
   my ($self, $job, $command) = @_;

   my $runid = bson64id;
   my $token = substr create_token, 0, 32;

   return {
      appclass  => $self->config->appclass,
      command   => $command,
      debug     => $self->debug,
      directory => $job->directory,
      errfile   => $job->err_file,
      job_id    => $job->id,
      outfile   => $job->out_file,
      port      => $self->port,
      runid     => $runid,
      servers   => $self->servers,
      token     => $token,
      worker    => $self->worker,
   };
}

sub _dispatch_message {
   my ($self, $job, $adjective, $runid) = @_;

   my $cmd  = $job->command;
   my $host = $job->host;
   my $name = $job->job_name;
   my $user = $job->user_name;

   return "${name}[${runid}]: ${adjective} ${user}\@${host} ${cmd}";
}

sub _dispatch_job {
   my ($self, $ipc_ssh, $job, $args) = @_;

   if ($job->host eq 'localhost') {
      $args->{config} = $self->config;
      $args->{log} = $self->log;

      my $response = $self->worker->new($args)->dispatch;
      my $name     = $job->job_name;
      my $runid    = $args->{runid};

      $self->log->debug("${name}[${runid}]: ${response}");
   }
   else {
      my $user    = $job->user_name;
      my $calls   = [['dispatch', [%{$args}]]];
      my $options = { calls => $calls, host => $job->host, user => $user };

      $self->provisioner->add_provisioning($options);
      $ipc_ssh->call($args->{runid}, $options); # Calls ssh_caller
   }

   return;
}

my $identity_file_cache = {};

sub _get_identity_file {
   my ($self, $args) = @_;

   my $host = $args->{host};
   my $user = $args->{user};
   my $key  = "${user}\@${host}";

   return $identity_file_cache->{$key} if exists $identity_file_cache->{$key};

   my $config = $self->config;
   my $dir    = $config->ssh_dir;
   my $prefix = lc distname $config->appclass;
   my @files  = (
      "${prefix}-${host}-${user}",
      "${prefix}-${host}",
      "${prefix}-${user}",
      $prefix
   );

   for my $path (map { $dir->catfile("${_}.priv") } @files) {
      return $identity_file_cache->{$key} = $path if $path->exists;
   }

   return;
}

sub _increment_try_count {
   my ($self, $job) = @_;

   my $jobid = $job->id;
   my $key   = "retry_count-${jobid}";
   my $count = $self->redis_client->get($key) // 0;

   $self->redis_client->set_with_ttl($key, $count + 1, 86400);
   return;
}

sub _input_event_cleanup {
   my ($self, $name, $ev_rs, $event) = @_;

   my $job        = $event->job;
   my $runid      = $event->runid;
   my $transition = $event->transition;
   my $jobid      = $job->id;
   my $retry_key  = "retry_count-${jobid}";

   $job->delete if $job->delete_after && $transition eq 'finish';

   $self->redis_client->del($retry_key) if $transition eq 'finish';

   if ($runid && includes $transition, [qw(fail finish terminate)]) {
      $self->redis_client->del("event_token-${runid}");
   }

   if (includes $transition, [qw(fail terminate)]) {
      my $label   = $job->label;
      my $message = "Job ${label} failed";
      my $leader  = ucfirst "${name}.event_cleanup";
      my $count   = $self->redis_client->get($retry_key) // 0;

      if ($job->nretrys && $job->nretrys >= $count) {
         $self->log->warn("${leader}: ${message}");
         $ev_rs->create({ job_id => $jobid, transition => 'activate' });
         $ev_rs->create({ job_id => $jobid, transition => 'force_start' });
      }
      else {
         $self->log->alert("${leader}: ${message}");
         $self->redis_client->del($retry_key);
         $self->_alert_subscribers($name, $message);
      }
   }

   return;
}

sub _process_event {
   my ($self, $name, $event) = @_;

   my $cols  = { $event->get_inflated_columns };
   my $js_rs = $self->schema->resultset('JobState');
   my $fail  = $js_rs->create_and_or_update($event);

   return $cols unless $fail;

   my $job     = $fail->[0];
   my $trans   = $fail->[1];
   my $e       = $fail->[2];
   my $reason  = length $e->class > 16 ? 'Exception' : $e->class;
   my $message = "Job ${job} transition ${trans} rejected - ${reason}";

   $cols->{rejected} = $reason;
   $self->log->debug("${name}: ${message}");
   $self->log->error("${name}: ${e}") if $reason eq 'Exception';

   return $cols;
}

sub _process_kill_event {
   my ($self, $name, $event, $ipc_ssh) = @_;

   my $pev      = $self->_process_event($name, $event);
   my $success  = $pev->{rejected} ? FALSE : TRUE;
   my $job      = $event->job;
   my $pev_rs   = $self->schema->resultset('ProcessedEvent');
   my $last_pev = $pev_rs->find_last_start($job);

   if ($success && $last_pev) {
      my $runid   = $last_pev->runid;
      my $args    = $self->_dispatch_args($job, 'kill_job');
      my $message = $self->_dispatch_message($job, 'Killing', $runid);

      $self->log->info($message);
      $args->{runid} = $runid;
      $args->{token} = $self->redis_client->get("event_token-${runid}");
      $self->_dispatch_job($ipc_ssh, $job, $args);
   }

   $pev_rs->create($pev);
   $event->delete;
   return $success;
}

sub _process_start_event {
   my ($self, $name, $event, $ipc_ssh) = @_;

   my $pev     = $self->_process_event($name, $event);
   my $success = $pev->{rejected} ? FALSE : TRUE;
   my $job     = $event->job;

   if ($success && $job->type eq 'job') {
      my $args    = $self->_dispatch_args($job, $job->command);
      my $message = $self->_dispatch_message($job, 'Starting', $args->{runid});
      my $runid   = $args->{runid};
      my $key     = "event_token-${runid}";

      $pev->{runid} = $runid;
      $self->redis_client->set_with_ttl($key, $args->{token}, 86400);
      $self->_increment_try_count($job);
      $self->_dispatch_job($ipc_ssh, $job, $args);
      $self->log->info($message);
   }
   elsif ($success && $job->type eq 'box') {
      my $options = { job_id => $job->id, transition => 'started' };

      $self->schema->resultset('Event')->create($options);
   }

   $self->schema->resultset('ProcessedEvent')->create($pev);
   $event->delete;
   return $success;
}

use namespace::autoclean;

1;

__END__

=back

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<IPC::PerlSSH>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module. Please report problems to
http://rt.cpan.org/NoAuth/Bugs.html?Dist=App-MCP.
Patches are welcome

=head1 Acknowledgements

Larry Wall - For the Perl programming language

=head1 Author

Peter Flanigan, C<< <pjfl@cpan.org> >>

=head1 License and Copyright

Copyright (c) 2025 Peter Flanigan. All rights reserved

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See L<perlartistic>

This program is distributed in the hope that it will be useful,
but WITHOUT WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE

=cut

# Local Variables:
# mode: perl
# tab-width: 3
# End:
