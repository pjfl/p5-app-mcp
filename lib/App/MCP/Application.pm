package App::MCP::Application;

use version;

use App::MCP::Constants    qw( COMMA FALSE NUL TRUE OK SPC TRANSITION_ENUM );
use Unexpected::Types      qw( ArrayRef HashRef LoadableClass NonEmptySimpleStr
                               NonZeroPositiveInt Object Str );
use App::MCP::Util         qw( concise_duration create_token distname
                               trigger_input_handler trigger_output_handler );
use Class::Usul::Cmd::Util qw( elapsed ensure_class_loaded includes );
use English                qw( -no_match_vars );
use List::Util             qw( first );
use Scalar::Util           qw( weaken );
use Web::ComposableRequest::Util
                           qw( bson64id );
use IPC::PerlSSH;
use Try::Tiny;
use Moo;

with 'App::MCP::Role::Schema';

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

=item C<servers>

A comma separated list of scheduling servers

=cut

has 'servers' =>
   is      => 'lazy',
   isa     => Str,
   default => sub { join COMMA, @{shift->config->servers} };

=item C<worker>

The L<worker|App::MCP::Worker> classname

=cut

has 'worker' =>
   is      => 'lazy',
   isa     => NonEmptySimpleStr,
   default => sub { shift->config->appclass . '::Worker' };

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

has '_provisioned'  => is => 'ro', isa => HashRef, default => sub { {} };

with 'App::MCP::Role::Redis';
with 'App::MCP::Role::JSONParser';
with 'App::MCP::Role::Webpush';

=back

=head1 Subroutines/Methods

Defines the following methods;

=over 3

=item C<cron_job_handler>

   $exit_code = $self->cron_job_handler($notifier_name, $daemon_pid);

=cut

sub cron_job_handler {
   my ($self, $name, $daemon_pid) = @_;

   $self->_cron_log_interval($name);

   my $schema  = $self->schema;
   my $job_rs  = $schema->resultset('Job');
   my $jobs    = $job_rs->active_crontab($self->_output_transitions);
   my $ev_rs   = $schema->resultset('Event');
   my $trigger = FALSE;

   for my $job (grep { $_->should_start_now } $jobs->all) {
      next if $job->condition && !$job->start_condition;

      $ev_rs->create({ job_id => $job->id, transition => 'start' });
      $trigger = TRUE;
   }

   trigger_output_handler $daemon_pid if $trigger;
   return OK;
}

=item C<event_stream_handler>

   $exit_code = $self->event_stream_handler($notifier_name, $daemon_pid);

=cut

# TODO: Implement event stream output method for a client
sub event_stream_handler {
   my ($self, $name, $daemon_pid) = @_;

   my $cache = $self->redis_client;
   my @events;

   for my $key ($cache->keys('event_stream-*')) {
      push @events, $self->json_parser->decode($cache->get($key));
      $cache->del($key);
   }

   return OK unless scalar @events;

   my $events = $self->json_parser->encode([@events]);

   for my $key ($cache->keys('event_subscription-*')) {
      my $user_id = (split m{ \- }mx, $key)[1];
      my $encoded = $cache->get($key) or next;
      my $subscription;

      try   { $subscription = $self->json_parser->decode($encoded) }
      catch { $cache->del($key) };

      next unless $subscription;

      my $method = '_event_stream_' . $subscription->{method};

      next unless $self->can($method);

      $subscription->{user_id} = $user_id;
      $self->$method($name, $subscription, $events);
   }

   return OK;
}

=item C<input_handler>

   $exit_code = $self->input_handler($notifier_name, $daemon_pid);

=cut

sub input_handler {
   my ($self, $name, $daemon_pid) = @_;

   my $schema  = $self->schema;
   my $where   = { transition => $self->_input_transitions };
   my $options = { order_by => { -asc => 'me.id' }, prefetch => 'job' };
   my $events  = $schema->resultset('Event')->search($where, $options);
   my $pev_rs  = $schema->resultset('ProcessedEvent');
   my $trigger = TRUE;

   while ($trigger) {
      $trigger = FALSE;

      for my $event ($events->all) {
         $schema->txn_do(sub {
            my $pev = $self->_process_event($name, $event);

            $trigger = TRUE unless $pev->{rejected};

            $pev_rs->create($pev);
            $event->delete;

            $event->job->delete if $event->job->delete_after
               && $event->transition eq 'finished';
         });
      }

      trigger_output_handler $daemon_pid if $trigger;
      $events->reset;
   }

   trigger_output_handler $daemon_pid;
   return OK;
}

=item C<ipc_ssh_caller>

   $hash_ref = $self->ipc_ssh_caller($notifier, $runid, \%options);

The keys of the C<options> hash reference are;

=over 3

=item C<calls>

=item C<host>

=item C<user>

=back

=cut

sub ipc_ssh_caller {
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

      my $cb = $call->[2];

      $self->$cb($leader, $results, $call, $resp, $args) if defined $cb;
   }

   return $results;
}

=item C<ipc_ssh_callback>

   $self->ipc_ssh_calback($notifier, \@args?);

The C<args> array reference should contain;

=over 3

=item C<runid>

=item C<results>

=back

=cut

sub ipc_ssh_callback {
   my ($self, $notifier, $args) = @_;

   my ($runid, $results) = @{$args // []};

   return unless $results;

   my $key  = $results->{provisioned}->{key};
   my $val  = $results->{provisioned}->{value};
   my $name = $notifier->name;

   $self->log->info("${name}[${runid}]: Provisioned ${key} ${val}")
      if $self->_remote_provisioned($key, $val);

   return;
}

=item C<output_handler>

   $exit_code = $self->output_handler($name, $daemon_pid, $ipc_ssh);

=cut

sub output_handler {
   my ($self, $name, $daemon_pid, $ipc_ssh) = @_;

   my $schema  = $self->schema;
   my $options = { prefetch => 'job' };
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

# Private methods
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

   if ($job->host ne 'localhost') {
      my $user    = $job->user_name;
      my $calls   = [['dispatch', [%{$args}]]];
      my $options = { calls => $calls, host => $job->host, user => $user };

      $self->_ipc_ssh_add_provisioning($options);
      $ipc_ssh->call($args->{runid}, $options); # Calls ipc_ssh_caller
   }
   else {
      ensure_class_loaded $self->worker;

      $args->{config} = $self->config;
      $args->{log} = $self->log;

      my $response = $self->worker->new($args)->dispatch;
      my $name     = $job->job_name;
      my $runid    = $args->{runid};

      $self->log->debug("${name}[${runid}]: ${response}");
   }

   return;
}

sub _event_stream_web_push {
   my ($self, $name, $subscription, $events) = @_;

   my $leader  = ucfirst "${name}.web_push";
   my $user_id = $subscription->{user_id};
   my $options = { content => { events => $events } };
   my $res     = $self->service_worker_push($user_id, $options);

   $self->log->error("${leader}: " . $res->{error}) unless $res->{success};
   $self->log->debug("${leader}: " . $res->{message}) if $res->{success};
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

sub _install_cpan_minus {
   return shift->_install_remote('install_cpan_minus', @_);
}

sub _install_distribution {
   return shift->_install_remote('install_distribution', @_);
}

sub _install_remote {
   my ($self, $method, $calls, $file) = @_;

   my $config   = $self->config;
   my $appclass = $config->appclass;

   unshift @{$calls}, [$method, [$appclass, $file]];

   return if $file =~ m{ \A [a-zA-Z0-9_]+ : }mx;

   my $path = $config->sharedir->catfile($file);

   unshift @{$calls}, ['writefile', [$appclass, $file, $path->all]];
   return;
}

sub _ipc_ssh_add_provisioning {
   my ($self, $args) = @_;

   my $host = $args->{host};
   my $user = $args->{user};

   return if $self->_remote_provisioned("${user}\@${host}");

   my $appclass  = $self->config->appclass;
   my $calls     = $args->{calls};
   my $installer = '_ipc_ssh_install_worker';
   my $worker    = $self->worker;

   unshift @{$calls}, ['provision', [$appclass, $worker], $installer];
   return;
}

sub _ipc_ssh_install_worker {
   my ($self, $leader, $results, $call, $result, $args) = @_;

   my $dist      = distname $self->worker;
   my $share     = $self->config->sharedir;
   my $filter    = qr{ \b $dist - ([0-9\.]+) \.tar\.gz \z }mx;
   my $our_ver   = (sort map { $_ =~ $filter; qv($1) } map { $_->basename }
                    $share->filter(sub { $_ =~ $filter })->all_files)[-1];
   my ($rem_ver) = $result =~ m{ \A version= (.+) \z }mx;
   my $key       = $args->{user}.'@'.$args->{host};

   $our_ver //= qv('0.0.0');
   $rem_ver = qv($rem_ver // '0.0.0');
   $self->log->debug("${leader}: Worker current - ${key} ${rem_ver}");

   if ($rem_ver >= $our_ver) {
      $results->{provisioned} = { key => $key, value => "${rem_ver}" };
      return;
   }

   my $tarball = $share->catfile(my $file = "${dist}-${our_ver}.tar.gz");

   return $self->log->error("${leader}: File ${tarball} not found")
      unless $tarball->exists;

   $self->log->debug("${leader}: Worker upgrade - ${rem_ver} to ${our_ver}");
   unshift @{$args->{calls}}, ['distclean', [$self->config->appclass]];

   # TODO: Need to force reload of worker after upgrade
   $self->_install_distribution($args->{calls}, $file);
   $self->_install_distribution($args->{calls}, 'local::lib');
   $self->_install_cpan_minus  ($args->{calls}, 'App-cpanminus.tar.gz');
   return;
}

sub _process_event {
   my ($self, $name, $event) = @_;

   my $cols  = { $event->get_inflated_columns };
   my $js_rs = $self->schema->resultset('JobState');
   my $fail  = $js_rs->create_and_or_update($event);

   return $cols unless $fail;

   my $mesg = 'Job ' . $fail->[0] . ' event ' . $fail->[1] .
              ' rejected - ' . $fail->[2]->class;

   $self->log->debug("${name}: ${mesg}");
   $cols->{rejected} = length $fail->[2]->class > 16
      ? 'Exception' : $fail->[2]->class;
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
      my $args    = $self->_dispatch_args($job, 'kill_job');
      my $message = $self->_dispatch_message($job, 'Killing', $last_pev->runid);

      $self->log->info($message);
      $args->{runid} = $pev->{runid} = $last_pev->runid;
      $args->{token} = $pev->{token} = $last_pev->token;
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

      $self->log->info($message);
      $pev->{runid} = $args->{runid};
      $pev->{token} = $args->{token};
      $self->_dispatch_job($ipc_ssh, $job, $args);
   }
   elsif ($success && $job->type eq 'box') {
      my $options = { job_id => $job->id, transition => 'started' };

      $self->schema->resultset('Event')->create($options);
   }

   $self->schema->resultset('ProcessedEvent')->create($pev);
   $event->delete;
   return $success;
}

sub _remote_provisioned {
   my ($self, $key, $val) = @_;

   $self->_provisioned->{$key} = $val if defined $val;

   return $self->_provisioned->{$key};
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
