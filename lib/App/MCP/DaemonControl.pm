# @(#)$Ident: DaemonControl.pm 2013-04-30 23:32 pjf ;

package App::MCP::DaemonControl;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 2 $ =~ /\d+/gmx );
use parent qw(Daemon::Control);

sub new {
   my ($self, $args) = @_; my $stop_signals = delete $args->{stop_signals};

   my $new = $self->SUPER::new( $args );

   $new->{stop_signals} = $stop_signals || 'TERM,1,TERM,1,INT,1,KILL,1';

   return $new;
}

sub do_stop {
   my $self = shift; $self->read_pid;

   if ($self->pid and $self->pid_running) {
      my @t = split m{ [,] }msx, $self->stop_signals; my $len = int (@t / 2);

      for my $i (0 .. $len) {
         kill  $t[ 2 * $i ], $self->pid;
         sleep $t[ 2 * $i + 1 ];
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

=head1 Version

This documents version v0.1.$Revision: 2 $

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
