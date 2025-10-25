package App::MCP::Application;

use version;

use App::MCP::Constants          qw( COMMA FALSE LOG_KEY_WIDTH
                                     NUL TRUE OK SPC TRANSITION_ENUM );
use Unexpected::Types            qw( HashRef LoadableClass NonEmptySimpleStr
                                     NonZeroPositiveInt Object );
use App::MCP::Util               qw( concise_duration create_token distname
                                     trigger_input_handler
                                     trigger_output_handler );
use Async::IPC::Functions        qw( log_debug log_error log_info log_warn );
use Class::Usul::Cmd::Util       qw( elapsed );
use English                      qw( -no_match_vars );
use List::Util                   qw( first );
use Scalar::Util                 qw( weaken );
use Web::ComposableRequest::Util qw( bson64id );
use Async::IPC::Constants        qw( );
use IPC::PerlSSH;
use Try::Tiny;
use Moo;

with 'App::MCP::Role::Schema';

Async::IPC::Constants->Log_Key_Width( LOG_KEY_WIDTH );

# Public attributes
has 'app' =>
   is       => 'ro',
   isa      => Object,
   handles  => ['config', 'debug', 'log'],
   init_arg => 'builder',
   required => TRUE;

has 'port' =>
   is      => 'lazy',
   isa     => NonZeroPositiveInt,
   default => sub { shift->config->port };

has 'worker' =>
   is      => 'lazy',
   isa     => NonEmptySimpleStr,
   default => sub { shift->config->appclass.'::Worker' };

# Private attributes
has '_provisioned'  => is => 'ro', isa => HashRef, default => sub { {} };

# Public methods
sub cron_job_handler {
   my ($self, $name, $sig_hndlr_pid) = @_;

   $self->_cron_log_interval($name);

   my $trigger = FALSE;
   my $schema  = $self->schema;
   my $job_rs  = $schema->resultset('Job');
   my $ev_rs   = $schema->resultset('Event');
   my $jobs    = $job_rs->search({
      'state.name'        => 'active',
      'me.crontab'        => { '!=' => NUL },
      'events.transition' => [ undef, { '!=' => 'start' } ],
   }, {
      'columns' => [qw( condition crontab events.transition
                        id state.name state.updated )],
      'join'    => ['state', 'events'],
   });

   for my $job (grep { $_->should_start_now } $jobs->all) {
      if (!$job->condition || $job->current_condition) {
         $ev_rs->create({ job_id => $job->id, transition => 'start' });
         $trigger = TRUE;
      }
   }

   trigger_output_handler $sig_hndlr_pid if $trigger;
   return OK;
}

sub input_handler {
   my ($self, $name, $sig_hndlr_pid) = @_;

   my $schema  = $self->schema;
   my $pev_rs  = $schema->resultset('ProcessedEvent');
   my $events  = $schema->resultset('Event')->search(
      { transition => [ grep { $_ ne 'start' } @{TRANSITION_ENUM()} ] },
      { order_by   => { -asc => 'me.id' }, prefetch => 'job' }
   );
   my $trigger = TRUE;

   while ($trigger) {
      $trigger = FALSE;

      for my $event ($events->all) {
         $schema->txn_do(sub {
            my $p_ev = $self->_process_event($name, $event);

            $trigger = TRUE unless $p_ev->{rejected};

            $pev_rs->create($p_ev);
            $event->delete;
         });
      }

      trigger_output_handler $sig_hndlr_pid if $trigger;
      $events->reset;
   }

   trigger_output_handler $sig_hndlr_pid;
   return OK;
}

sub ipc_ssh_add_provisioning {
   my ($self, $args) = @_;

   my $host = $args->{host};
   my $user = $args->{user};

   return if $self->_remote_provisioned("${user}\@${host}");

   my $appclass  = $self->config->appclass;
   my $calls     = $args->{calls};
   my $installer = 'ipc_ssh_install_worker';
   my $worker    = $self->worker;

   unshift @{$calls}, ['provision', [$appclass, $worker], $installer];
   return;
}

sub ipc_ssh_caller {
   my ($self, $name, $notifier, $runid, $args) = @_;

   my @options = (Host => $args->{host}, User => $args->{user});
   my $file    = $self->_get_identity_file($args);

   push @options, 'SshOptions', ['-i', $file] if $file;

   my $ips    = IPC::PerlSSH->new(@options);
   my $log    = $self->log;
   my $logger = sub { $log, $name, $runid };
   my $failed = FALSE;

   try   { $ips->use_library($self->config->library_class) }
   catch { log_error $logger, "Use library - ${_}"; $failed = TRUE };

   return FALSE if $failed;

   my $results = {};

   while (defined (my $call = shift @{$args->{calls}})) {
      my $resp;

      try   { $resp = $ips->call($call->[0], @{$call->[1]}) }
      catch { log_error $logger, "Call failed - ${_}"; $failed = TRUE };

      return FALSE if $failed;

      log_debug $logger, "Call succeeded - ${resp}";

      my $cb = $call->[2];

      $self->$cb($logger, $results, $call, $resp, $args) if defined $cb;
   }

   return $results;
}

sub ipc_ssh_callback {
   my ($self, $name, $notifier, $args) = @_;

   my ($runid, $results) = @{$args // []};

   return unless $results;

   my $prov = $results->{provisioned};
   my $key  = $prov->{key};
   my $val  = $prov->{value};

   log_info $self->log, $name, $PID, "Provisioned ${runid} ${key} ${val}"
      if $self->_remote_provisioned($key, $val);

   return;
}

sub ipc_ssh_install_worker {
   my ($self, $logger, $results, $call, $result, $args) = @_;

   my $dist      = distname $self->worker;
   my $share     = $self->config->sharedir;
   my $filter    = qr{ \b $dist - ([0-9\.]+) \.tar\.gz \z }mx;
   my $our_ver   = (sort map { $_ =~ $filter; qv($1) } map { $_->basename }
                    $share->filter(sub { $_ =~ $filter })->all_files)[-1];
   my ($rem_ver) = $result =~ m{ \A version= (.+) \z }mx;
   my $key       = $args->{user}.'@'.$args->{host};

   $our_ver //= qv('0.0.0');
   $rem_ver = qv($rem_ver // '0.0.0');
   log_debug $logger, "Worker current - ${key} ${rem_ver}";

   if ($rem_ver >= $our_ver) {
      $results->{provisioned} = { key => $key, value => "${rem_ver}" };
      return;
   }

   my $tarball = $share->catfile(my $file = "${dist}-${our_ver}.tar.gz");

   return log_warn $logger, "File ${tarball} not found" unless $tarball->exists;

   log_debug $logger, "Worker upgrade - from ${rem_ver} to ${our_ver}";
   unshift @{$args->{calls}}, ['distclean', [$self->config->appclass]];

   # TODO: Need to force reload of worker after upgrade
   $self->_install_distribution($args->{calls}, $file);
   $self->_install_distribution($args->{calls}, 'local::lib');
   $self->_install_cpan_minus  ($args->{calls}, 'App-cpanminus.tar.gz');
   return;
}

sub output_handler {
   my ($self, $name, $sig_hndlr_pid, $ipc_ssh) = @_;

   my $schema  = $self->schema;
   my $where   = { transition => 'start' };
   my $ev_rs   = $schema->resultset('Event');
   my $events  = $ev_rs->search($where, { prefetch => 'job' });
   my $trigger = TRUE;

   while ($trigger) {
      $trigger = FALSE;

      for my $event ($events->all) {
         my $job_id  = $event->job->id;
         my $success = $schema->txn_do(sub {
            return $self->_process_start_event($name, $event, $ipc_ssh);
         });

         if ($success && $event->job->type eq 'box') {
            $ev_rs->create({ job_id => $job_id, transition => 'started' });
            trigger_input_handler $sig_hndlr_pid;
         }
         elsif ($success) { $trigger = TRUE }
         else {
            $ev_rs->create({ job_id => $job_id, transition => 'fail' });
            trigger_input_handler $sig_hndlr_pid;
         }
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

   log_info $self->log, $name, $PID, 'Elapsed ' . concise_duration($elapsed)
      if ($rem > $log_int - $spread or $rem < $spread);

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

sub _process_event {
   my ($self, $name, $event) = @_;

   my $cols  = { $event->get_inflated_columns };
   my $js_rs = $self->schema->resultset('JobState');
   my $r     = $js_rs->create_and_or_update($event) or return $cols;
   my $mesg  = 'Job ' . $r->[1] . ' event ' . $r->[0]
             . ' rejected - ' . $r->[2]->class;

   log_warn $self->log, $name, $PID, $mesg;
   $cols->{rejected} = $r->[2]->class;
   return $cols;
}

sub _process_start_event {
   my ($self, $name, $event, $ipc_ssh) = @_;

   my $p_ev = $self->_process_event($name, $event);

   if (!$p_ev->{rejected} && $event->job->type eq 'job') {
      my ($runid, $token) = $self->_start_job($ipc_ssh, $event->job);

      $p_ev->{runid} = $runid;
      $p_ev->{token} = $token;
   }

   $self->schema->resultset('ProcessedEvent')->create($p_ev);
   $event->delete;
   return $p_ev->{rejected} ? FALSE : TRUE;
}

sub _remote_provisioned {
   my ($self, $key, $val) = @_;

   $self->_provisioned->{$key} = $val if defined $val;

   return $self->_provisioned->{$key};
}

sub _start_job {
   my ($self, $ipc_ssh, $job) = @_;

   my $runid = bson64id;
   my $host  = $job->host;
   my $user  = $job->user_name;
   my $cmd   = $job->command;
   my $class = $self->config->appclass;
   my $token = substr create_token, 0, 32;
   my $args  = {
      appclass  => $class,
      command   => $cmd,
      debug     => $self->debug,
      directory => $job->directory,
      job_id    => $job->id,
      port      => $self->port,
      runid     => $runid,
      servers   => (join COMMA, @{$self->config->servers}),
      token     => $token,
      worker    => $self->worker,
   };
   my $calls = [['dispatch', [%{$args}]]];

   log_info $self->log, $job->job_name, $runid, "Start ${user}\@${host} ${cmd}";
   $args = { calls => $calls, host => $host, user => $user, };
   $self->ipc_ssh_add_provisioning($args);
   $ipc_ssh->call($runid, $args); # Calls ipc_ssh_caller
   return ($runid, $token);
}

sub _install_cpan_minus {
   return shift->_install_remote('install_cpan_minus', @_);
}

sub _install_distribution {
   return shift->_install_remote('install_distribution', @_);
}

use namespace::autoclean;

1;

__END__

=pod

=encoding utf8

=head1 Name

App::MCP::Application - One-line description of the modules purpose

=head1 Synopsis

   use App::MCP::Application;
   # Brief but working code examples

=head1 Description

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=back

=head1 Subroutines/Methods

=head1 Diagnostics

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

Copyright (c) 2024 Peter Flanigan. All rights reserved

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
