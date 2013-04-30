# @(#)$Ident: Async.pm 2013-04-30 23:33 pjf ;

package App::MCP::Async;

use feature qw(state);
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 2 $ =~ /\d+/gmx );

use Class::Usul::Moose;
use Class::Usul::Constants;
use English qw(-no_match_vars);
use IO::Async::Loop::EV;
use IO::Async::Channel;
use IO::Async::Timer::Periodic;
use POSIX   qw(WEXITSTATUS);

has 'builder' => is => 'ro',   isa => Object, weak_ref => TRUE;

has 'loop'    => is => 'lazy', isa => Object,
   default    => sub { IO::Async::Loop::EV->new };

sub new_notifier {
   my ($self, %p) = @_; my $log = $self->builder->log; my $loop = $self->loop;

   my $code = $p{code}; my $desc = $p{desc}; my $key = $p{key};

   my $logger = sub {
      my ($level, $pid, $msg) = @_; $log->$level( "${key}[${pid}]: ${msg}" );
   };

   my $notifier; my $pid;

   if ($p{type} eq 'function') {
      $notifier = App::MCP::AsyncFunction->new
         (  code         => $code,
            description  => $desc,
            exit_on_die  => TRUE,
            factory      => $self,
            log_key      => $key,
            max_workers  => $p{max_workers},
            setup        => [ $log->fh, [ 'keep' ] ], );

      $notifier->start;
      $p{parent} ? $p{parent}->add_child( $notifier ) : $loop->add( $notifier );
      $pid = $notifier->workers;
   }
   elsif ($p{type} eq 'process') {
      $notifier = App::MCP::AsyncProcess->new
         (  code         => $code,
            description  => $desc,
            factory      => $self,
            log_key      => $key,
            on_exit      => sub {
               my $pid = shift; my $rv = WEXITSTATUS( shift );

               $logger->( 'info', $pid, ucfirst "${desc} stopped ${rv}" );
            }, );

      $pid = $notifier->pid;
   }
   elsif ($p{type} eq 'routine') {
      my $input = IO::Async::Channel->new; my $msg = ucfirst "${desc} stopped";

      $notifier = App::MCP::AsyncRoutine->new
         (  channels_in  => [ $input ],
            code         => sub { $code->( $notifier, $input ) },
            description  => $desc,
            factory      => $self,
            log_key      => $key,
            on_exception => sub { $logger->( 'error', $pid, join ' - ', @_ ) },
            on_finish    => sub { $logger->( 'info',  $pid, $msg ) },
            setup        => [ $log->fh, [ 'keep' ] ], );

      $p{parent} ? $p{parent}->add_child( $notifier ) : $loop->add( $notifier );
      $pid = $notifier->pid;
   }
   else {
      $notifier = IO::Async::Timer::Periodic->new
         (  on_tick    => $code,
            interval   => $p{interval},
            reschedule => 'drift', );

      $notifier->start;
      $p{parent} ? $p{parent}->add_child( $notifier ) : $loop->add( $notifier );
      $pid = $PID;
   }

   $logger->( 'info', $pid, "Started ${desc}" );

   return $notifier;
}

sub uuid {
   state $uuid //= 0; return $uuid++;
}

__PACKAGE__->meta->make_immutable;

package # Hide from indexer
   App::MCP::AsyncFunction;

use parent q(IO::Async::Function);

use Class::Usul::Functions qw(arg_list);

sub new {
   my $self = shift; my $attr = arg_list( @_ );

   my $factory = delete $attr->{factory};
   my $desc    = delete $attr->{description};
   my $key     = delete $attr->{log_key};
   my $new     = $self->SUPER::new( %{ $attr } );

   $new->{description} = $desc;
   $new->{log        } = $factory->builder->log;
   $new->{log_key    } = $key;
   return $new;
}

sub call {
   my ($self, $runid, @args) = @_; my $log = $self->{log};

   my $logger = sub {
      my ($level, $cmd, $msg) = @_; $log->$level( "${cmd}[${runid}]: ${msg}" );
   };

   my $task = $self->SUPER::call
      (  args      => [ $runid, @args ],
         on_return => sub { $logger->( 'debug', ' CALL', 'Complete' ) },
         on_error  => sub { $logger->( 'error', ' CALL', $_[ 0 ]    ) }, );

   return $task;
}

sub stop {
   my $self = shift;
   my $key  = $self->{log_key};
   my $desc = $self->{description};

   for my $worker ($self->_worker_objects) {
      my $pid = $worker->pid;

      $self->{log}->info( "${key}[${pid}]: Stopping ${desc}" );
      $worker->stop;
   }

   return;
}

package # Hide from indexer
   App::MCP::AsyncProcess;

use Class::Usul::Functions qw(arg_list);

sub new { # Cannot get IO::Async::Process to plackup Twiggy, so this instead
   my $self    = shift;
   my $attr    = arg_list( @_ );
   my $factory = delete $attr->{factory};
   my $desc    = delete $attr->{description};
   my $key     = delete $attr->{log_key};
   my $new     = bless $attr, ref $self || $self;

   $new->{description} = $desc;
   $new->{log        } = $factory->builder->log;
   $new->{log_key    } = $key;

   my $r = $factory->builder->run_cmd( [ $new->{code} ], { async => 1 } );

   $factory->loop->watch_child( $new->{pid} = $r->{pid}, $new->{on_exit} );

   return $new;
}

sub is_running {
   return CORE::kill 0, $_[ 0 ]->{pid};
}

sub pid {
   return $_[ 0 ]->{pid};
}

sub stop {
   my $self = shift; $self->is_running or return;

   my $desc = $self->{description};
   my $key  = $self->{log_key};
   my $pid  = $self->{pid};

   $self->{log}->info( "${key}[${pid}]: Stopping ${desc}" );
   CORE::kill 'TERM', $pid;
   return;
}

package # Hide from indexer
   App::MCP::AsyncRoutine;

use parent q(IO::Async::Routine);

use Class::Usul::Constants;
use Class::Usul::Functions qw(arg_list);
use IPC::SysV              qw(IPC_PRIVATE S_IRUSR S_IWUSR IPC_CREAT);
use IPC::Semaphore;

sub new {
   my $self = shift; my $attr = arg_list( @_ );

   my $factory = delete $attr->{factory};
   my $desc    = delete $attr->{description};
   my $key     = delete $attr->{log_key};
   my $new     = $self->SUPER::new( %{ $attr } );
   my $id      = 1234 + $factory->uuid;
   my $s       = IPC::Semaphore->new( $id, 2, S_IRUSR | S_IWUSR | IPC_CREAT );

   $s->setval( 0, TRUE ); $s->setval( 1, FALSE );

   $new->{description} = $desc;
   $new->{log        } = $factory->builder->log;
   $new->{log_key    } = $key;
   $new->{semaphore  } = $s;
   return $new;
}

sub DESTROY {
   $_[ 0 ]->{semaphore}->remove; return;
}

sub await_trigger {
   $_[ 0 ]->{semaphore}->op( 1, -1, 0 ); return TRUE;
}

sub still_running {
   return $_[ 0 ]->{semaphore}->getval( 0 );
}

sub stop {
   my $self = shift; $self->is_running or return;

   my $desc = $self->{description};
   my $key  = $self->{log_key};
   my $pid  = $self->{pid};

   $self->{log}->info( "${key}[${pid}]: Stopping ${desc}" );
   $self->{semaphore}->setval( 0, FALSE );
   $self->trigger;
   return;
}

sub trigger {
   my $self = shift; my $semaphore = $self->{semaphore};

   $semaphore->getval( 1 ) < 1 and $semaphore->op( 1, 1, 0 );

   return;
}

1;

__END__

=pod

=head1 Name

App::MCP::Async - <One-line description of module's purpose>

=head1 Version

This documents version v0.1.$Revision: 2 $

=head1 Synopsis

   use App::MCP::Async;
   # Brief but working code examples

=head1 Description

=head1 Configuration and Environment

=head1 Subroutines/Methods

=head1 Diagnostics

=head1 Dependencies

=over 3

=item L<Class::Usul>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module.
Please report problems to the address below.
Patches are welcome

=head1 Acknowledgements

Larry Wall - For the Perl programming language

=head1 Author

Peter Flanigan, C<< <Support at RoxSoft dot co dot uk> >>

=head1 License and Copyright

Copyright (c) 2012 Peter Flanigan. All rights reserved

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
