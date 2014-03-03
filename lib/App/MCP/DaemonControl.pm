package App::MCP::DaemonControl;

use strictures;
use parent 'Daemon::Control';

sub new {
   my ($self, $args) = @_; my $stop_signals = delete $args->{stop_signals};

   my $new = $self->SUPER::new( $args );

   $new->{stop_signals} = $stop_signals || 'TERM,0,TERM,0,INT,0,KILL,0';

   return $new;
}

sub do_stop {
   my $self = shift; $self->read_pid;

   my $kill_timeout = $self->can( 'kill_timeout' ) ? $self->kill_timeout : 1;

   if ($self->pid and $self->pid_running) {
      my @t = split m{ [,] }msx, $self->stop_signals; my $len = int (@t / 2);

      for my $i (0 .. $len) {
         kill $t[ 2 * $i ], $self->pid;

         my $timeout = $t[ 2 * $i + 1 ];
            $timeout < 1 and $timeout = $kill_timeout;

         for (1 .. $timeout) {
            $self->pid_running or last; sleep 1;
         }

         $self->pid_running or last;
      }

      if ($self->pid_running) {
         $self->pretty_print( 'Failed to Stop', 'red' ); exit 1;
      }

      $self->pretty_print( 'Stopped' );
   }
   else { $self->pretty_print( 'Not Running', 'red' ) }

   $self->pid_file and unlink $self->pid_file;
   return;
}

sub stop_signals {
   return $_[ 0 ]->{stop_signals};
}

1;

__END__

=pod

=head1 Name

App::MCP::DaemonControl - <One-line description of module's purpose>

=head1 Synopsis

   use App::MCP::DaemonControl;
   # Brief but working code examples

=head1 Description

=head1 Configuration and Environment

=head1 Subroutines/Methods

=head1 Diagnostics

=head1 Dependencies

=over 3

=item L<Class::Usul>

=item L<Daemon::Control>

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

Copyright (c) 2014 Peter Flanigan. All rights reserved

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
