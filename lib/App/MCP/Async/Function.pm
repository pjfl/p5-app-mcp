# @(#)Ident: Function.pm 2013-06-01 13:44 pjf ;

package App::MCP::Async::Function;

use feature                 qw(state);
use version; our $VERSION = qv( sprintf '0.2.%d', q$Rev: 16 $ =~ /\d+/gmx );

use App::MCP::Functions     qw(log_leader log_recv_error read_exactly);
use App::MCP::Async::Process;
use Class::Usul::Moose;
use Class::Usul::Constants;
use Class::Usul::Functions  qw(throw);
use English                 qw(-no_match_vars);
use Fcntl                   qw(F_SETFL O_NONBLOCK);
use Storable                qw(nfreeze thaw);
use TryCatch;

extends q(App::MCP::Async::Base);

# Public attributes
has 'channels'       => is => 'ro',  isa => SimpleStr, default => 'i';

has 'interval'       => is => 'ro',  isa => PositiveInt, default => 1;

has 'is_running'     => is => 'rwp', isa => Bool, default => TRUE;

has 'max_calls'      => is => 'ro',  isa => PositiveOrZeroInt, default => 0;

has 'max_workers'    => is => 'ro',  isa => PositiveInt, default => 1;

has 'worker_args'    => is => 'ro',  isa => HashRef, default => sub { {} };

has 'worker_index'   => is => 'ro',  isa => ArrayRef, default => sub { [] };

has 'worker_objects' => is => 'ro',  isa => HashRef, default => sub { {} };

# Construction
around 'BUILDARGS' => sub {
   my ($next, $self, @args) = @_; my $args = $self->$next( @args );

   my $channels    = delete $args->{channels   };
   my $log_key     = delete $args->{log_key    };
   my $max_calls   = delete $args->{max_calls  };
   my $max_workers = delete $args->{max_workers};
   my $attr        = { builder     => $args->{builder},
                       description => $args->{description},
                       worker_args => $args, };

   defined $channels  and $attr->{channels   } = $channels;
   $log_key           and $attr->{log_key    } = $log_key;
   defined $max_calls and $attr->{max_calls  } = $max_calls;
   $max_workers       and $attr->{max_workers} = $max_workers;
   return $attr;
};

# Public methods
sub call {
   my ($self, @args) = @_; $self->is_running or return;

   my $index  = $self->_next_worker;
   my $pid    = $self->worker_index->[ $index ] || 0;
   my $worker = $self->worker_objects->{ $pid };

   $worker or $worker = $self->_new_worker( $index, @args );
   $worker->send( @args );
   return;
}

sub stop {
   my $self = shift; $self->_set_is_running( FALSE );

   my $lead = log_leader 'debug', $self->log_key, $self->pid;

   $self->log->debug( $lead.'Stopping '.$self->description.' pool' );

   my $workers = $self->worker_objects;

   $workers->{ $_ }->stop for (keys %{ $workers });

   $self->loop->watch_child( 0 );
   return;
}

# Private methods
sub _build_pid {
   return $_[ 0 ]->loop->uuid;
}

sub _call_handler {
   my ($self, $args, $id) = @_; my $code = $args->{code};

   my $log    = $self->log; my $max_calls = $self->max_calls;

   my $reader = $args->{args_pipe} ? $args->{args_pipe}->[ 0 ] : undef;

   my $writer = $args->{ret_pipe } ? $args->{ret_pipe }->[ 1 ] : undef;

   return sub {
      my $count = 0; my $lead = log_leader 'error', 'EXEC', $id;

      while (TRUE) {
         my $args = undef; my $rv = undef;

         if ($reader) {
            my $red = read_exactly( $reader, my $lenbuffer, 4 );

            defined ($rv = log_recv_error( $log, $id, $red )) and return $rv;
            $red = read_exactly( $reader, $args, unpack( 'I', $lenbuffer ) );
            defined ($rv = log_recv_error( $log, $id, $red )) and return $rv;
         }

         try        { $rv = $code->( @{ $args ? thaw $args : [] } );
                      $writer and __send_rv( $writer, $log, $id, $rv ) }
         catch ($e) { $log->error( $lead.$e ) }

         $max_calls and ++$count >= $max_calls and return OK;
      }
   }
}

sub _new_worker {
   my ($self, $index, $id) = @_; my $args = { %{ $self->worker_args } };

   my $on_exit = delete $args->{on_exit}; my $workers = $self->worker_objects;

   $self->channels =~ m{ i }mx
      and $args->{args_pipe} = __nonblocking_write_pipe_pair();
   $self->channels =~ m{ o }mx
      and $args->{ret_pipe } = __nonblocking_write_pipe_pair();
   $args->{code       } = $self->_call_handler( $args, $id );
   $args->{description} = (lc $self->log_key)." worker ${index}";
   $args->{log_key    } = 'WORKER';
   $args->{on_exit    } = sub { delete $workers->{ $_[ 0 ] }; $on_exit->( @_ )};

   my $worker = App::MCP::Async::Process->new( $args ); my $pid = $worker->pid;

   $workers->{ $pid } = $worker; $self->worker_index->[ $index ] = $pid;

   return $worker;
}

sub _next_worker {
   my $self = shift; state $worker //= -1;

   $worker++; $worker >= $self->max_workers and $worker = 0;

   return $worker;
}

# Private functions
sub __nonblocking_write_pipe_pair {
   my ($r, $w); pipe $r, $w or throw 'No pipe';

   fcntl $w, F_SETFL, O_NONBLOCK; $w->autoflush( TRUE );

   binmode $r; binmode $w;

   return [ $r, $w ];
}

sub __send_rv {
   my ($writer, $log, @args) = @_;

   my $rec  = nfreeze [ @args ];
   my $buf  = pack( 'I', length $rec ).$rec;
   my $len  = $writer->syswrite( $buf, length $buf );
   my $lead = log_leader 'error', 'SENDRV', $args[ 0 ];

   defined $len or $log->error( $lead.$OS_ERROR );

   return;
}

1;

__END__

=pod

=encoding utf8

=head1 Name

App::MCP::Async::Function - One-line description of the modules purpose

=head1 Synopsis

   use App::MCP::Async::Function;
   # Brief but working code examples

=head1 Version

This documents version v0.2.$Rev: 16 $ of L<App::MCP::Async::Function>

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

Peter Flanigan, C<< <pjfl@cpan.org> >>

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
