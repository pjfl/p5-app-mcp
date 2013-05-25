# @(#)Ident: Function.pm 2013-05-25 12:24 pjf ;

package App::MCP::Async::Function;

use strict;
use warnings;
use feature                 qw(state);
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 3 $ =~ /\d+/gmx );

use App::MCP::Async::Process;
use Class::Usul::Constants;
use Class::Usul::Functions  qw(arg_list pad throw);
use English                 qw(-no_match_vars);
use Fcntl                   qw(F_SETFL O_NONBLOCK);
use Scalar::Util            qw(blessed);
use Storable                qw(thaw);

# Construction
sub new {
   my $self = shift; my $args = arg_list( @_ );

   my $attr = { log            => $args->{factory}->builder->log,
                max_calls      => delete $args->{max_calls  } || 0,
                max_workers    => delete $args->{max_workers} || 1,
                pid            => $args->{factory}->uuid,
                worker_args    => $args,
                worker_index   => [],
                worker_objects => {}, };

   return bless $attr, blessed $self || $self;
}

# Public methods
sub call {
   my ($self, @args) = @_; my $index = $self->_next_worker;

   my $pid    = $self->{worker_index}->[ $index ] || 0;
   my $worker = $self->{worker_objects}->{ $pid };

   $worker or $worker = $self->_new_worker( $index, @args );

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

# Private methods
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

   my $worker  = App::MCP::Async::Process->new( $args ); my $pid = $worker->pid;

   $workers->{ $pid } = $worker; $self->{worker_index}->[ $index ] = $pid;

   return $worker;
}

sub _next_worker {
   my $self = shift; state $worker //= -1;

   $worker++; $worker >= $self->{max_workers} and $worker = 0;

   return $worker;
}

# Private functions
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
   my ($r, $w); pipe $r, $w or throw 'No pipe';

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

This documents version v0.1.$Rev: 3 $ of L<App::MCP::Async::Function>

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
