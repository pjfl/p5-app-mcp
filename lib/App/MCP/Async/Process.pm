# @(#)Ident: Process.pm 2013-05-27 20:09 pjf ;

package App::MCP::Async::Process;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 6 $ =~ /\d+/gmx );

use App::MCP::Functions     qw(log_on_error pad5z read_exactly);
use Class::Usul::Constants;
use Class::Usul::Functions  qw(arg_list pad throw);
use English                 qw(-no_match_vars);
use Scalar::Util            qw(blessed weaken);
use Storable                qw(nfreeze thaw);
use TryCatch;

sub new {
   my $self      = shift; my $attr = arg_list( @_ );

   my $factory   = delete $attr->{factory  } or throw 'No factory';
   my $args_pipe = delete $attr->{args_pipe};
   my $on_exit   = delete $attr->{on_exit  };
   my $on_return = delete $attr->{on_return};
   my $ret_pipe  = delete $attr->{ret_pipe };

   $attr->{code} or throw 'No code';
   $attr->{log } = $factory->builder->log or throw 'No log';
   $attr->{wtr } = $args_pipe->[ 1 ] if $args_pipe;
   $attr->{rdr } = $ret_pipe->[ 0 ]  if $ret_pipe;

   my $new       = bless  $attr, blessed $self || $self;
   my $weak_ref  = $new; weaken( $weak_ref );
   my $code      = sub { $new->{code}->( $weak_ref ) };
   my $r         = $factory->builder->run_cmd( [ $code ], { async => TRUE } );
   my $pid       = $new->{pid} = $r->{pid};

   $on_exit   and $factory->loop->watch_child( $pid, $on_exit );
   $on_return and $new->_watch_read_handle( $factory, $on_return );

   return $new;
}

sub is_running {
   return CORE::kill 0, $_[ 0 ]->{pid};
}

sub pid {
   return $_[ 0 ]->{pid};
}

sub send {
   my ($self, @args) = @_; my $did = pad5z $args[ 0 ];

   $self->{wtr} or throw error => 'Pid [_1] no write handle', args => [ $did ];

   my $rec   = nfreeze [ @args ];
   my $bytes = pack( 'I', length $rec ).$rec;
   my $len   = $self->{wtr}->syswrite( $bytes, length $bytes );

   defined $len or $self->{log}->error( " SEND[${did}]: ${OS_ERROR}" );

   return;
}

sub stop {
   my $self = shift; $self->is_running or return;

   my $key  = $self->{log_key}; my $did = pad5z $self->{pid};

   $self->{log}->info( "${key}[${did}]: Stopping ".$self->{description} );
   CORE::kill 'TERM', $self->{pid};
   return;
}

sub _watch_read_handle {
   my ($self, $factory, $code) = @_; my $rdr = $self->{rdr} or return;

   my $did = pad5z $self->{pid}; my $log = $self->{log};

   $factory->loop->watch_read_handle( $self->{pid}, $rdr, sub {
      my ($args, $rv); my $red = read_exactly( $rdr, my $lenbuffer, 4 );

      defined ($rv = log_on_error( $log, $did, $red )) and return $rv;
      $red = read_exactly( $rdr, $args, unpack( 'I', $lenbuffer ) );
      defined ($rv = log_on_error( $log, $did, $red )) and return $rv;

      try        { $code->( @{ $args ? thaw $args : [] } ) }
      catch ($e) { $log->error( " RECV[${did}]: ${e}" ) }

      return;
   } );

   return;
}

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

This documents version v0.1.$Rev: 6 $ of L<App::MCP::Async::Process>

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
