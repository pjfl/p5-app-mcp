package App::MCP::Application;

use namespace::autoclean;
use version;

use App::MCP::Constants    qw( COMMA FALSE LOG_KEY_WIDTH NUL TRUE OK SPC );
use App::MCP::Util         qw( trigger_output_handler );
use Async::IPC::Functions  qw( log_debug log_error log_info log_warn );
use Class::Usul::Functions qw( bson64id create_token distname elapsed );
use Class::Usul::Types     qw( HashRef LoadableClass NonEmptySimpleStr
                               NonZeroPositiveInt Object Plinth );
use English                qw( -no_match_vars );
use IPC::PerlSSH;
use List::Util             qw( first );
use Scalar::Util           qw( weaken );
use Try::Tiny;
use Moo;

Async::IPC::Functions->log_key_width( LOG_KEY_WIDTH );

my $Identitfy_File_Cache = {};

# Public attributes
has 'app'    => is => 'ro',   isa => Plinth,
   handles   => [ 'config', 'debug', 'log' ], init_arg => 'builder',
   required  => TRUE;

has 'port'   => is => 'lazy', isa => NonZeroPositiveInt,
   builder   => sub { $_[ 0 ]->config->port };

has 'worker' => is => 'lazy', isa => NonEmptySimpleStr,
   builder   => sub { $_[ 0 ]->config->appclass.'::Worker' };

# Private attributes
has '_provisioned'  => is => 'ro',   isa => HashRef, default => sub { {} };

has '_schema'       => is => 'lazy', isa => Object,  reader  => 'schema',
   builder          => sub {
      my $self = shift; my $extra = $self->config->connect_params;
      $self->schema_class->connect( @{ $self->get_connect_info }, $extra ) };

has '_schema_class' => is => 'lazy', isa => LoadableClass,
   builder          => sub { $_[ 0 ]->config->schema_classes->{ 'mcp-model' } },
   reader           => 'schema_class';

with 'Class::Usul::TraitFor::ConnectInfo';

# Private methods
my $_cron_log_interval = sub {
   my ($self, $name) = @_;

   my $log_int = $self->config->cron_log_interval or return;
   my $elapsed = elapsed;
   my $rem     = $elapsed % $log_int;
   my $spread  = $self->config->clock_tick_interval / 2;

   ($rem > $log_int - $spread or $rem < $spread)
      and log_info $self->log, $name, $PID, "Elapsed ${elapsed}";
   return;
};

my $_get_identity_file = sub {
   my ($self, $args) = @_; my $host = $args->{host}; my $user = $args->{user};

   my $key    = "${user}\@${host}"; exists $Identitfy_File_Cache->{ $key }
      and return $Identitfy_File_Cache->{ $key };
   my $dir    = $self->config->ssh_dir;
   my $prefix = distname $self->config->appclass;
   my @files  = ("${host}-${user}", $user, $host);

   for my $path (map { $dir->catfile( "${prefix}_${_}.priv" ) } @files) {
      $path->exists and return $Identitfy_File_Cache->{ $key } = $path;
   }

   return $Identitfy_File_Cache->{ $key } = $self->config->identity_file;
};

my $_install_remote = sub {
   my ($self, $method, $calls, $file) = @_;

   my $conf = $self->config; my $appclass = $conf->appclass;

   unshift @{ $calls }, [ $method, [ $appclass, $file ] ];

   $file =~ m{ \A [a-zA-Z0-9_]+ : }mx and return;

   my $path = $conf->sharedir->catfile( $file );

   unshift @{ $calls }, [ 'writefile', [ $appclass, $file, $path->all ] ];
   return;
};

my $_process_event = sub {
   my ($self, $name, $js_rs, $event) = @_;

   my $cols = { $event->get_inflated_columns };
   my $r    = $js_rs->create_and_or_update( $event ) or return $cols;
   my $mesg = 'Job '.$r->[ 1 ].SPC.$r->[ 0 ].' event rejected';

   log_debug $self->log, $name, $PID, $mesg;
   $cols->{rejected} = $r->[ 2 ]->class;
   return $cols;
};

my $_remote_provisioned = sub {
   defined $_[ 2 ] and $_[ 0 ]->_provisioned->{ $_[ 1 ] } = $_[ 2 ];

   return $_[ 0 ]->_provisioned->{ $_[ 1 ] };
};

my $_start_job = sub {
   my ($self, $ipc_ssh, $job) = @_;

   my $runid = bson64id;
   my $host  = $job->host;
   my $user  = $job->user;
   my $cmd   = $job->command;
   my $class = $self->config->appclass;
   my $token = substr create_token, 0, 32;
   my $args  = { appclass  => $class,
                 command   => $cmd,
                 debug     => $self->debug,
                 directory => $job->directory,
                 job_id    => $job->id,
                 port      => $self->port,
                 runid     => $runid,
                 servers   => (join COMMA, @{ $self->config->servers }),
                 token     => $token,
                 worker    => $self->worker, };
   my $calls = [ [ 'dispatch', [ %{ $args } ] ], ];

   log_info $self->log, $job->name, $runid, "Start ${user}\@${host} ${cmd}";
   $args = { calls => $calls, host => $host, user => $user, };
   $self->ipc_ssh_add_provisioning( $args );
   $ipc_ssh->call( $runid, $args ); # Calls ipc_ssh_caller
   return ($runid, $token);
};

my $_install_cpan_minus = sub {
   return shift->$_install_remote( 'install_cpan_minus', @_ );
};

my $_install_distribution = sub {
   return shift->$_install_remote( 'install_distribution', @_ );
};

# Public methods
sub cron_job_handler {
   my ($self, $name, $sig_hndlr_pid) = @_;

   $self->$_cron_log_interval( $name );

   my $trigger = FALSE;
   my $schema  = $self->schema;
   my $job_rs  = $schema->resultset( 'Job' );
   my $ev_rs   = $schema->resultset( 'Event' );
   my $jobs    = $job_rs->search
      ( { 'state.name'        => 'active',
          'me.crontab'        => { '!=' => NUL },
          'events.transition' => [ undef, { '!=' => 'start' } ], },
        { 'columns'           => [ qw( condition crontab events.transition
                                       id state.name state.updated ) ],
          'join'              => [ 'state', 'events' ], } );

   for my $job (grep { $_->should_start_now } $jobs->all) {
      (not $job->condition or $job->eval_condition) and $trigger = TRUE
       and $ev_rs->create( { job_id => $job->id, transition => 'start' } );
   }

   $trigger and trigger_output_handler $sig_hndlr_pid;
   return OK;
}

sub input_handler {
   my ($self, $name, $sig_hndlr_pid) = @_; my $trigger = TRUE;

   while ($trigger) {
      $trigger = FALSE;

      my $schema = $self->schema;
      my $ev_rs  = $schema->resultset( 'Event' );
      my $js_rs  = $schema->resultset( 'JobState' );
      my $pev_rs = $schema->resultset( 'ProcessedEvent' );
      my $events = $ev_rs->search
         ( { transition => [ qw( activate finish started terminate ) ] },
           { order_by   => { -asc => 'me.id' },
             prefetch   => 'job_rel' } );

      for my $event ($events->all) {
         $schema->txn_do( sub {
            my $p_ev = $self->$_process_event( $name, $js_rs, $event );

            $p_ev->{rejected} or $trigger = TRUE;
            $pev_rs->create( $p_ev ); $event->delete;
         } );
      }

      $trigger and trigger_output_handler $sig_hndlr_pid;
   }

   trigger_output_handler $sig_hndlr_pid;
   return OK;
}

sub ipc_ssh_add_provisioning {
   my ($self, $args) = @_; my $host = $args->{host}; my $user = $args->{user};

   $self->$_remote_provisioned( "${user}\@${host}" ) and return;

   my $appclass  = $self->config->appclass;  my $calls  = $args->{calls};
   my $installer = 'ipc_ssh_install_worker'; my $worker = $self->worker;

   unshift @{ $calls }, [ 'provision', [ $appclass, $worker ], $installer ];
   return;
}

sub ipc_ssh_caller {
   my ($self, $name, $notifier, $runid, $args) = @_;

   my $failed = FALSE;
   my $log    = $self->log;
   my $ips    = IPC::PerlSSH->new
      ( Host       => $args->{host},
        User       => $args->{user},
        SshOptions => [ '-i', $self->$_get_identity_file( $args ) ], );
   my $logger = sub { $log, $name, $runid };

   try   { $ips->use_library( $self->config->library_class ) }
   catch { log_error $logger, "Store failed - ${_}"; $failed = TRUE };

   $failed and return FALSE; my $results = {};

   while (defined (my $call = shift @{ $args->{calls} })) {
      my $res;

      try   { $res = $ips->call( $call->[ 0 ], @{ $call->[ 1 ] } ) }
      catch { log_error $logger, "Call failed - ${_}"; $failed = TRUE };

      $failed and return FALSE; log_debug $logger, "Call succeeded - ${res}";

      my $method = $call->[ 2 ]; defined $method
         and $self->$method( $logger, $results, $call, $res, $args );
   }

   return $results;
}

sub ipc_ssh_callback {
   my ($self, $name, $notifier, $args) = @_;

   my ($runid, $results) = @{ $args // [] }; $results or return;

   my ($mesg, $key, $res, $val); $res = $results->{provisioned}
      and $key  = $res->{key}
      and $self->$_remote_provisioned( $key, $val = $res->{value} )
      and $mesg = "Provisioned ${runid} ${key} ${val}"
      and log_info $self->log, $name, $PID, $mesg;

   return;
}

sub ipc_ssh_install_worker {
   my ($self, $logger, $results, $call, $result, $args) = @_;

   my  $dist     =  distname $self->worker;
   my  $share    =  $self->config->sharedir;
   my  $filter   =  qr{ \b $dist - ([0-9\.]+) \.tar\.gz \z }mx;
   my  $our_ver  = (sort map { $_ =~ $filter; qv( $1 ) } map { $_->basename }
                    $share->filter( sub { $_ =~ $filter } )->all_files)[ -1 ];
   my ($rem_ver) =  $result =~ m{ \A version= (.+) \z }mx;
   my  $key      =  $args->{user}.'@'.$args->{host};

   $our_ver //= qv( '0.0.0' ); $rem_ver = qv( $rem_ver // '0.0.0' );
   log_debug $logger, "Worker current - ${key} ${rem_ver}";

   $rem_ver >= $our_ver
      and $results->{provisioned} = { key => $key, value => "${rem_ver}" }
      and return;

   my  $tarball  =  $share->catfile( my $file = "${dist}-${our_ver}.tar.gz" );

   $tarball->exists or return log_warn $logger, "File ${tarball} not found";

   log_debug $logger, "Worker upgrade - from ${rem_ver} to ${our_ver}";
   unshift @{ $args->{calls} }, [ 'distclean', [ $self->config->appclass ] ];

   # TODO: Need to force reload of worker after upgrade
   $self->$_install_distribution( $args->{calls}, $file );
   $self->$_install_distribution( $args->{calls}, 'local::lib' );
   $self->$_install_cpan_minus  ( $args->{calls}, 'App-cpanminus.tar.gz' );
   return;
}

sub output_handler {
   my ($self, $name, $ipc_ssh) = @_; my $trigger = TRUE;

   while ($trigger) {
      $trigger = FALSE;

      my $schema = $self->schema;
      my $ev_rs  = $schema->resultset( 'Event' );
      my $js_rs  = $schema->resultset( 'JobState' );
      my $pev_rs = $schema->resultset( 'ProcessedEvent' );
      my $events = $ev_rs->search( { transition => 'start' },
                                   { prefetch   => 'job_rel' } );

      for my $event ($events->all) {
         $schema->txn_do( sub {
            my $p_ev = $self->$_process_event( $name, $js_rs, $event );

            unless ($p_ev->{rejected}) {
               my ($runid, $token)
                  = $self->$_start_job( $ipc_ssh, $event->job_rel );

               $p_ev->{runid} = $runid; $p_ev->{token} = $token;
               $trigger = TRUE;
            }

            $pev_rs->create( $p_ev ); $event->delete;
         } );
      }
   }

   return OK;
}

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

=item L<Class::Usul>

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

Copyright (c) 2015 Peter Flanigan. All rights reserved

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
