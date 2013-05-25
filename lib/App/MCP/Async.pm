# @(#)$Ident: Async.pm 2013-05-25 11:45 pjf ;

package App::MCP::Async;

use feature qw(state);
use version; our $VERSION = qv( sprintf '0.2.%d', q$Rev: 2 $ =~ /\d+/gmx );

use Class::Usul::Moose;
use Class::Usul::Constants;
use Class::Usul::Functions qw(pad throw);
use POSIX                  qw(WEXITSTATUS);

has 'builder' => is => 'ro',   isa => Object, weak_ref => TRUE;

has 'loop'    => is => 'lazy', isa => Object,
   default    => sub { App::MCP::AsyncLoop->new };

sub new_notifier {
   my ($self, %p) = @_; my $log = $self->builder->log; my $notifier;

   my $code = $p{code}; my $desc = $p{desc}; my $key = $p{key};

   my $logger = sub {
      my ($level, $pid, $msg) = @_; $pid = pad $pid, 5, 0, 'left';

      $log->$level( "${key}[${pid}]: ${msg}" ); return;
   };

   if ($p{type} eq 'function') {
      $notifier = App::MCP::AsyncFunction->new
         (  code        => $code,
            description => $desc,
            factory     => $self,
            log_key     => $key,
            max_workers => $p{max_workers},
            on_exit     => sub {
               my $pid = shift; my $rv = WEXITSTATUS( shift );

               $logger->( 'info', $pid, ucfirst "${desc} stopped ${rv}" );
            }, );
   }
   elsif ($p{type} eq 'periodical') {
      $notifier = App::MCP::AsyncPeriodical->new
         (  autostart   => TRUE,
            code        => $code,
            description => $desc,
            factory     => $self,
            log_key     => $key,
            interval    => $p{interval} );
   }
   elsif ($p{type} eq 'process') {
      $notifier = App::MCP::AsyncProcess->new
         (  code        => $code,
            description => $desc,
            factory     => $self,
            log_key     => $key,
            on_exit     => sub {
               my $pid = shift; my $rv = WEXITSTATUS( shift );

               $logger->( 'info', $pid, ucfirst "${desc} stopped ${rv}" );
            }, );
   }
   elsif ($p{type} eq 'routine') {
      $notifier = App::MCP::AsyncRoutine->new
         (  code        => $code,
            description => $desc,
            factory     => $self,
            log_key     => $key,
            on_exit     => sub {
               my $pid = shift; my $rv = WEXITSTATUS( shift );

               $logger->( 'info', $pid, ucfirst "${desc} stopped ${rv}" );
            }, );
   }
   else { throw error => 'Notifier [_1] type unknown', args => [ $p{type} ] }

   $logger->( 'info', $notifier->pid, "Started ${desc}" );

   return $notifier;
}

sub uuid {
   state $uuid //= 0; return $uuid++;
}

__PACKAGE__->meta->make_immutable;

package App::MCP::AsyncLoop;

use AnyEvent;
use Async::Interrupt;
use Class::Usul::Constants;
use Class::Usul::Functions qw(arg_list throw);
use Scalar::Util           qw(blessed);

sub new {
   my $self = shift; my $attr = arg_list( @_ );

   $attr->{cv} = AnyEvent->condvar;

   $attr->{signals} ||= {}; $attr->{timers} ||= {}; $attr->{watchers} ||= {};

   return bless $attr, blessed $self || $self;
}

sub attach_signal {
   my ($self, $sig, $cb) = @_;

   $self->{signals}->{ $sig } = AnyEvent->signal( signal => $sig, cb => $cb );

   return;
}

sub detach_signal {
   my ($self, $sig) = @_; delete $self->{signals}->{ $sig }; return;
}

sub run {
   my $self = shift; $self->{cv}->recv; return;
}

sub start_timer {
   my ($self, $id, $cb, $period) = @_;

   $self->{timers}->{ $id } = AnyEvent->timer
      ( after => $period, cb => $cb, interval => $period );

   return;
}

sub stop_timer {
   my ($self, $id) = @_; delete $self->{timers}->{ $id }; return;
}

sub watch_child {
   my ($self, $pid, $cb) = @_; my $w = $self->{watchers};

   if ($pid == 0) {
      $w->{condvars}->{ $_ }->recv for (keys %{ $w->{condvars} });

      $self->{cv}->send;
   }
   else {
      my $cv = $w->{condvars}->{ $pid } = AnyEvent->condvar;

      $w->{children}->{ $pid } = AnyEvent->child( pid => $pid, cb => sub {
         $cb->( @_ ); $cv->send } );
   }

   return;
}

package App::MCP::AsyncProcess;

use Class::Usul::Functions qw(arg_list pad);
use English                qw(-no_match_vars);
use Scalar::Util           qw(blessed weaken);
use Storable               qw(nfreeze);

sub new {
   my $self = shift; my $attr = arg_list( @_ );

   my $factory = delete $attr->{factory}; my $pipe = delete $attr->{pipe};

   $attr->{log} = $factory->builder->log;
   $pipe and $attr->{hndl} = $pipe->[ 1 ];

   my $new  = bless $attr, blessed $self || $self;
   my $weak = $new; weaken( $weak );
   my $code = sub { $new->{code}->( $weak ) };
   my $r    = $factory->builder->run_cmd( [ $code ], { async => 1 } );

   $factory->loop->watch_child( $new->{pid} = $r->{pid}, $new->{on_exit} );

   return $new;
}

sub is_running {
   return CORE::kill 0, $_[ 0 ]->{pid};
}

sub pid {
   return $_[ 0 ]->{pid};
}

sub send {
   my ($self, @args) = @_; my $id = pad $args[ 0 ], 5, 0, 'left';

   my $hndl  = $self->{hndl}
               or throw error => 'Process [_1] has no handle', args => [ $id ];
   my $rec   = nfreeze [ @args ];
   my $bytes = pack( 'I', length $rec ).$rec;
   my $len   = $hndl->syswrite( $bytes, length $bytes );

   defined $len or $self->{log}->error( " SEND[${id}]: ${OS_ERROR}" );

   return;
}

sub stop {
   my $self = shift; $self->is_running or return;

   my $desc = $self->{description};
   my $key  = $self->{log_key};
   my $pid  = $self->{pid};
   my $did  = pad $pid, 5, 0, 'left';

   $self->{log}->info( "${key}[${did}]: Stopping ${desc}" );
   CORE::kill 'TERM', $pid;
   return;
}

package App::MCP::AsyncFunction;

use feature qw(state);

use Class::Usul::Constants;
use Class::Usul::Functions qw(arg_list pad throw);
use English                qw(-no_match_vars);
use Fcntl                  qw(F_SETFL O_NONBLOCK);
use Scalar::Util           qw(blessed);
use Storable               qw(thaw);

sub new {
   my $self    = shift;
   my $args    = arg_list( @_ );
   my $factory = $args->{factory};
   my $attr    = { log            => $factory->builder->log,
                   max_calls      => 0,
                   max_workers    => delete $args->{max_workers} || 1,
                   pid            => $factory->uuid,
                   worker_args    => $args,
                   worker_index   => [],
                   worker_objects => {}, };

   return bless $attr, blessed $self || $self;
}

sub call {
   my ($self, @args) = @_; my $index = $self->_next_worker;

   my $pid    = $self->{worker_index}->[ $index ] || 0;
   my $worker = $self->{worker_objects}->{ $pid };

   $worker or $worker = $self->_new_worker( $index, $args[ 0 ] );

   $worker->send( @args );
   return;
}

sub pid {
   return $_[ 0 ]->{pid};
}

sub stop {
   my $self = shift; my $workers = $self->{worker_objects};

   $workers->{ $_ }->stop for (keys %{ $workers });

   return;
}

sub _call_handler {
   my ($self, $args, $id) = @_; my $code = $args->{code};

   my $count = 0; my $hndl = $args->{pipe}->[ 0 ]; my $log = $self->{log};

   my $max_calls = $self->{max_calls}; my $readbuff = q();

   return sub {
      while (TRUE) {
         my $red = __read_exactly( $hndl, my $lenbuffer, 4 ); my $rv;

         defined ($rv = __log_on_error( $log, $id, $red )) and return $rv;

         $red = __read_exactly( $hndl, my $rec, unpack( 'I', $lenbuffer ) );

         defined ($rv = __log_on_error( $log, $id, $red )) and return $rv;

         $code->( @{ thaw $rec } ) or return FAILED;

         $max_calls and ++$count > $max_calls and return OK;
      }
   }
}

sub _new_worker {
   my ($self, $index, $id) = @_; my $args = { %{ $self->{worker_args} } };

   my $on_exit = delete $args->{on_exit}; my $workers = $self->{worker_objects};

   $args->{pipe   } = __nonblocking_write_pipe_pair();
   $args->{code   } = $self->_call_handler( $args, $id );
   $args->{on_exit} = sub { delete $workers->{ $_[ 0 ] }; $on_exit->( @_ ) };

   my $worker  = App::MCP::AsyncProcess->new( $args ); my $pid = $worker->pid;

   $workers->{ $pid } = $worker; $self->{worker_index}->[ $index ] = $pid;

   return $worker;
}

sub _next_worker {
   my $self = shift; state $worker //= -1;

   $worker++; $worker >= $self->{max_workers} and $worker = 0;

   return $worker;
}

sub __log_on_error {
   my ($log, $id, $red) = @_; my $did = pad $id, 5, 0, 'left';

   unless (defined $red) {
      $log->error( " RECV[${did}]: ${OS_ERROR}" ); return FAILED;
   }

   unless (length $red) {
      $log->info( " RECV[${did}]: EOF" ); return OK;
   }

   return;
}

sub __nonblocking_write_pipe_pair {
   my ($r, $w);  pipe $r, $w or throw 'No pipe';

   fcntl $w, F_SETFL, O_NONBLOCK; $w->autoflush( TRUE );

   binmode $r; binmode $w;

   return [ $r, $w ];
}

sub __read_exactly {
   $_[ 1 ] = q();

   while ((my $have = length $_[ 1 ]) < $_[ 2 ]) {
      my $red = read( $_[ 0 ], $_[ 1 ], $_[ 2 ] - $have, $have );

      defined $red or return; $red or return q();
   }

   return $_[ 2 ];
}

package App::MCP::AsyncPeriodical;

use Class::Usul::Functions qw(arg_list pad);
use Scalar::Util           qw(blessed);

sub new {
   my $self    = shift;
   my $attr    = arg_list( @_ );
   my $factory = delete $attr->{factory};

   $attr->{id  } = $factory->uuid;
   $attr->{log } = $factory->builder->log;
   $attr->{loop} = $factory->loop;

   my $new     =  bless $attr, blessed $self || $self;

   $new->{autostart} and $new->start;

   return $new;
}

sub pid {
   return $_[ 0 ]->{id};
}

sub start {
   my $self = shift;

   $self->{loop}->start_timer( $self->{id}, $self->{code}, $self->{interval} );

   return;
}

sub stop {
   my $self = shift;
   my $desc = $self->{description};
   my $key  = $self->{log_key};
   my $id   = $self->{id};
   my $did  = pad $id, 5, 0, 'left';

   $self->{log}->info( "${key}[${did}]: Stopping ${desc}" );
   $self->{loop}->stop_timer( $id );
   return;
}

package App::MCP::AsyncRoutine;

use base q(App::MCP::AsyncProcess);

use Class::Usul::Constants;
use Class::Usul::Functions qw(arg_list pad throw);
use IPC::SysV              qw(IPC_PRIVATE S_IRUSR S_IWUSR IPC_CREAT);
use IPC::Semaphore;

sub new {
   my $self = shift;
   my $attr = arg_list( @_ );
   my $id   = 1234 + $attr->{factory}->uuid;
   my $s    = IPC::Semaphore->new( $id, 2, S_IRUSR | S_IWUSR | IPC_CREAT );

   $s->setval( 0, TRUE ); $s->setval( 1, FALSE ); $attr->{semaphore} = $s;

   return $self->SUPER::new( $attr );
}

sub DESTROY {
   defined $_[ 0 ]->{semaphore} and $_[ 0 ]->{semaphore}->remove; return;
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
   my $did  = pad $self->{pid}, 5, 0, 'left';

   $self->{log}->info( "${key}[${did}]: Stopping ${desc}" );
   $self->{semaphore}->setval( 0, FALSE );
   $self->trigger;
   return;
}

sub trigger {
   my $self = shift; my $semaphore = $self->{semaphore} or throw 'No semaphore';

   my $val = $semaphore->getval( 1 ) // 0;

   $val < 1 and $semaphore->op( 1, 1, 0 );
   return;
}

1;

__END__

=pod

=head1 Name

App::MCP::Async - <One-line description of module's purpose>

=head1 Version

This documents version v0.2.$Rev: 2 $

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

Copyright (c) 2013 Peter Flanigan. All rights reserved

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
