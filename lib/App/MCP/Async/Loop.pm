# @(#)Ident: Loop.pm 2013-05-31 18:14 pjf ;

package App::MCP::Async::Loop;

use strict;
use warnings;
use feature                 qw(state);
use version; our $VERSION = qv( sprintf '0.2.%d', q$Rev: 15 $ =~ /\d+/gmx );

use AnyEvent;
use Async::Interrupt;
use Class::Usul::Functions  qw(arg_list);
use English                 qw(-no_match_vars);
use Scalar::Util            qw(blessed);

my $handles = {}; my $signals = {}; my $timers = {}; my $watchers = {};

sub new {
   my $self = shift; return bless arg_list( @_ ), blessed $self || $self;
}

sub attach_signal {
   my ($self, $signal, $cb) = @_;

   unless ($self->{sigattaches}->{ $signal }) {
      my @attaches; $self->watch_signal( $signal, sub {
         for my $attachment (@attaches) { $attachment->() }
      } );

      $self->{sigattaches}->{ $signal } = \@attaches;
   }

   push @{ $self->{sigattaches}->{ $signal } }, $cb;
   return \$self->{sigattaches}->{ $signal }->[ -1 ];
}

sub detach_signal {
   my ($self, $signal, $id) = @_;

   # Can't use grep because we have to preserve the addresses
   my $attaches = $self->{sigattaches}->{ $signal } or return;

   for (my $i = 0; $i < @{ $attaches }; ) {
      not $id and splice @{ $attaches }, $i, 1, () and next;
      $id == \$attaches->[ $i ] and splice @{ $attaches }, $i, 1, () and last;
      $i++;
   }

   scalar @{ $attaches } and return; $self->unwatch_signal( $signal );
   delete $self->{sigattaches}->{ $signal }; return;
}

sub restart_timer {
   my ($self, $id, $after, $interval) = @_; my $ref = $timers->{ $PID } ||= {};

   my $cb = exists $ref->{ $id } ? $self->stop_timer( $id ) : 0;

   return $cb ? $self->start_timer( $id, $cb, $after, $interval ) : undef;
}

sub start {
   my $self = shift; (local $self->{cv} = AnyEvent->condvar)->recv; return;
}

sub start_timer {
   my ($self, $id, $cb, $after, $interval) = @_;

   my $t = $timers->{ $PID } ||= {}; my @args = (after => $after, cb => $cb);

   not defined $interval and push @args, 'interval', $after;
   defined $interval and $interval and push @args, 'interval', $interval;
   $t->{ $id } = [ $cb, AnyEvent->timer( @args ) ];
   return $t->{ $id }->[ 1 ];
}

sub stop {
   $_[ 0 ]->{cv}->send; return;
}

sub stop_timer {
   my $cb; my $id = $_[ 1 ]; my $ref = $timers->{ $PID } ||= {};

   exists $ref->{ $id } and $cb = $ref->{ $id }->[ 0 ]
      and undef $ref->{ $id }->[ 1 ];

   delete $ref->{ $id }; return $cb;
}

sub unwatch_child {
   my $ref = $watchers->{ $PID } ||= {}; return delete $ref->{ $_[ 1 ] };
}

sub unwatch_read_handle {
   my $ref = $handles->{ $PID } ||= {}; return delete $ref->{ 'r'.$_[ 1 ] };
}

sub unwatch_signal {
   my $ref = $signals->{ $PID } ||= {}; return delete $ref->{ $_[ 1 ] };
}

sub unwatch_time {
   return $_[ 0 ]->stop_timer( $_[ 1 ] );
}

sub unwatch_write_handle {
   my $ref = $handles->{ $PID } ||= {}; return delete $ref->{ 'w'.$_[ 1 ] };
}

sub uuid {
   state $uuid //= 1; return $uuid++;
}

sub watch_child {
   my ($self, $pid, $cb) = @_; my $w = $watchers->{ $PID } ||= {};

   if ($pid == 0) {
      for (sort { $a <=> $b } keys %{ $w }) {
         $w->{ $_ }->[ 0 ]->recv; undef $w->{ $_ }->[ 0 ];
         undef $w->{ $_ }->[ 1 ]; delete $w->{ $_ };
      }

      return;
   }

   my $cv = $w->{ $pid }->[ 0 ] = AnyEvent->condvar;

   return   $w->{ $pid }->[ 1 ] = AnyEvent->child( pid => $pid, cb => sub {
      $cb->( @_ ); $cv->send } );
}

sub watch_read_handle {
   my ($self, $fh, $cb) = @_; my $h = $handles->{ $PID } ||= {};

   return $h->{ "r${fh}" } = AnyEvent->io( cb => $cb, fh => $fh, poll => 'r' );
}

sub watch_signal {
   my ($self, $signal, $cb) = @_; my $s = $signals->{ $PID } ||= {};

   return $s->{ $signal } = AnyEvent->signal( signal => $signal, cb => $cb );

}

sub watch_time {
   my ($self, $id, $cb, $period, $flag) = @_;

   my $after = $flag ? $period - time : $period; $after or return;

   return $self->start_timer( $id, $cb, $after, 0 );
}

sub watch_write_handle {
   my ($self, $fh, $cb) = @_; my $h = $handles->{ $PID } ||= {};

   return $h->{ "w${fh}" } = AnyEvent->io( cb => $cb, fh => $fh, poll => 'w' );
}

1;

__END__

=pod

=encoding utf8

=head1 Name

App::MCP::Async::Loop - One-line description of the modules purpose

=head1 Synopsis

   use App::MCP::Async::Loop;
   # Brief but working code examples

=head1 Version

This documents version v0.2.$Rev: 15 $ of L<App::MCP::Async::Loop>

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
