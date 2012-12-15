# @(#)$Id$

package App::MCP::Async;

use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use Class::Usul::Moose;
use Class::Usul::Constants;
use Class::Usul::Functions qw(throw);
use English                qw(-no_match_vars);
use POSIX                  qw(WEXITSTATUS);
use IO::Async::Loop::EV;
use IO::Async::Channel;
use IO::Async::Routine;
use IO::Async::Timer::Periodic;

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
         (  code        => $code,
            exit_on_die => TRUE,
            factory     => $self,
            max_workers => $p{max_workers},
            setup       => [ $log->fh, [ 'keep' ] ], );

      $notifier->start; $loop->add( $notifier ); $pid = $notifier->workers;
   }
   elsif ($p{type} eq 'process') {
      $notifier = App::MCP::AsyncProcess->new
         (  code    => $code,
            factory => $self,
            on_exit => sub {
               my $pid = shift; my $rv = WEXITSTATUS( shift );

               $logger->( 'info', $pid, (ucfirst $desc)." stopped ${rv}" );
            }, );

      $pid = $notifier->pid;
   }
   elsif ($p{type} eq 'routine') {
      my $input = IO::Async::Channel->new; my $msg = ucfirst "${desc} stopped";

      $notifier = IO::Async::Routine->new
         (  channels_in  => [ $input ],
            code         => sub { $code->( $input ) },
            on_exception => sub { $logger->( 'error', $pid, join ' - ', @_ ) },
            on_finish    => sub { $logger->( 'info',  $pid, $msg ) },
            setup        => [ $log->fh, [ 'keep' ] ], );

      $loop->add( $notifier ); $pid = $notifier->pid;
   }
   else {
      $notifier = IO::Async::Timer::Periodic->new
         (  on_tick    => $code,
            interval   => $p{interval},
            reschedule => 'drift', );

      $notifier->start; $loop->add( $notifier ); $pid = $PID;
   }

   $logger->( 'info', $pid, "Started ${desc}" );

   return $notifier;
}

__PACKAGE__->meta->make_immutable;

package # Hide from indexer
   App::MCP::AsyncFunction;

use Class::Usul::Functions qw(arg_list);

use parent q(IO::Async::Function);

sub new {
   my $self = shift; my $attr = arg_list( @_ );

   my $factory = delete $attr->{factory}; my $builder = $factory->builder;

   my $new = $self->SUPER::new( %{ $attr } ); $new->{log} = $builder->log;

   return $new;
}

sub call {
   my ($self, $runid, @args) = @_; my $log = $self->log;

   my $logger = sub {
      my ($level, $cmd, $msg) = @_; $log->$level( "${cmd}[${runid}]: ${msg}" );
   };

   return $self->SUPER::call
      (  args      => [ $runid, @args ],
         on_return => sub { $logger->( 'debug', ' CALL', 'Complete' ) },
         on_error  => sub { $logger->( 'error', ' CALL', $_[ 0 ]    ) }, );
}

sub log {
   return $_[ 0 ]->{log};
}

sub stop { # TODO: Fix me. Seriously fucked off with IO::Async
   my $self = shift;

   for (grep { $_->pid } $self->_worker_objects) {
      $_->stop; CORE::kill 'KILL', $_->pid;
   }

   return;
}

package # Hide from indexer
   App::MCP::AsyncProcess;

sub new { # Cannot get IO::Async::Process to plackup Twiggy, so this instead
   my $self    = shift;
   my $new     = bless { @_ }, ref $self || $self;
   my $factory = delete $new->{factory};
   my $r       = $factory->builder->run_cmd( [ $new->{code} ], { async => 1 } );

   $factory->loop->watch_child( $new->{pid} = $r->{pid}, $new->{on_exit} );

   return $new;
}

sub is_running {
   return CORE::kill 0, $_[ 0 ]->pid;
}

sub kill {
   CORE::kill $_[ 1 ], $_[ 0 ]->pid;
}

sub pid {
   return $_[ 0 ]->{pid};
}

1;

__END__

=pod

=head1 Name

App::MCP::Async - <One-line description of module's purpose>

=head1 Version

0.1.$Revision$

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
