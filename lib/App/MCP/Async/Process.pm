# @(#)Ident: Process.pm 2013-05-29 20:38 pjf ;

package App::MCP::Async::Process;

use version; our $VERSION = qv( sprintf '0.2.%d', q$Rev: 10 $ =~ /\d+/gmx );

use App::MCP::Functions     qw(log_on_error padid padkey read_exactly);
use Class::Usul::Moose;
use Class::Usul::Constants;
use Class::Usul::Functions  qw(throw);
use English                 qw(-no_match_vars);
use Scalar::Util            qw(weaken);
use Storable                qw(nfreeze thaw);
use TryCatch;

extends q(App::MCP::Async::Base);

# Public attributes
has 'code'      => is => 'ro', isa => CodeRef, required => TRUE;

has 'on_exit'   => is => 'ro', isa => CodeRef | Undef;

has 'on_return' => is => 'ro', isa => CodeRef | Undef;

has 'reader'    => is => 'ro', isa => FileHandle | Undef;

has 'writer'    => is => 'ro', isa => FileHandle | Undef;

# Construction
around 'BUILDARGS' => sub {
   my ($next, $self, @args) = @_; my $attr = $self->$next( @args );

   my $factory   = $attr->{factory} or throw 'No factory';
   my $args_pipe = delete $attr->{args_pipe};
   my $ret_pipe  = delete $attr->{ret_pipe };

   $attr->{builder} = $factory->builder;
   $attr->{loop   } = $factory->loop;
   $attr->{reader } = $ret_pipe->[ 0 ]  if $ret_pipe;
   $attr->{writer } = $args_pipe->[ 1 ] if $args_pipe;
   return $attr;
};

sub BUILD {
   my $self = shift; $self->pid; # Trigger lazy build

   $self->on_exit   and $self->loop->watch_child( $self->pid, $self->on_exit );
   $self->on_return and $self->reader and $self->_watch_read_handle;
   return;
}

# Public methods
sub is_running {
   return CORE::kill 0, $_[ 0 ]->pid;
}

sub send {
   my ($self, @args) = @_; my $did = padid $args[ 0 ];

   $self->writer or throw error => 'Process [_1] no writer', args => [ $did ];

   my $rec = nfreeze [ @args ];
   my $buf = pack( 'I', length $rec ).$rec;
   my $len = $self->writer->syswrite( $buf, length $buf );
   my $key = padkey 'error', 'SEND';

   defined $len or $self->log->error( "${key}[${did}]: ${OS_ERROR}" );

   return;
}

sub stop {
   my $self = shift; $self->is_running or return;

   my $dkey = padkey 'info', $self->log_key; my $did = padid $self->pid;

   $self->log->info( "${dkey}[${did}]: Stopping ".$self->description );
   CORE::kill 'TERM', $self->pid;
   return;
}

# Private methods
sub _build_pid {
   my $self     = shift;
   my $weak_ref = $self; weaken( $weak_ref );
   my $code     = sub { $weak_ref->code->( $weak_ref ) };

   return $self->builder->run_cmd( [ $code ], { async => TRUE } )->pid;
}

sub _watch_read_handle {
   my $self = shift; my $code = $self->on_return;

   my $dkey = padkey 'error', 'RECV'; my $did = padid $self->pid;

   my $log  = $self->log; my $reader = $self->reader;

   $self->loop->watch_read_handle( $self->pid, $reader, sub {
      my ($args, $rv); my $red = read_exactly( $reader, my $lenbuffer, 4 );

      defined ($rv = log_on_error( $log, $did, $red )) and return $rv;
      $red = read_exactly( $reader, $args, unpack( 'I', $lenbuffer ) );
      defined ($rv = log_on_error( $log, $did, $red )) and return $rv;

      try        { $code->( @{ $args ? thaw $args : [] } ) }
      catch ($e) { $log->error( "${dkey}[${did}]: ${e}"  ) }

      return;
   } );

   return;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=encoding utf8

=head1 Name

App::MCP::Async::Process - One-line description of the modules purpose

=head1 Synopsis

   use App::MCP::Async::Process;
   # Brief but working code examples

=head1 Version

This documents version v0.2.$Rev: 10 $ of L<App::MCP::Async::Process>

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
