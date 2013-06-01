# @(#)Ident: Loop.pm 2013-06-01 16:38 pjf ;

package App::MCP::Async::Loop;

use strict;
use warnings;
use feature                 qw(state);
use version; our $VERSION = qv( sprintf '0.2.%d', q$Rev: 17 $ =~ /\d+/gmx );

use AnyEvent;
use Async::Interrupt;
use Class::Usul::Functions  qw(arg_list);
use English                 qw(-no_match_vars);
use Scalar::Util            qw(blessed);

my $_CACHE = {};

# Construction
sub new {
   my $self = shift; return bless arg_list( @_ ), blessed $self || $self;
}

# Public methods
sub restart_timer {
   my ($self, $id, $after, $interval) = @_; my $t = __cache( 'timers' );

   my $cb = exists $t->{ $id } ? $self->stop_timer( $id ) : 0;

   return $cb ? $self->start_timer( $id, $cb, $after, $interval ) : undef;
}

sub start {
   my $self = shift; (local $self->{cv} = AnyEvent->condvar)->recv; return;
}

sub start_timer {
   my ($self, $id, $cb, $after, $interval) = @_; my $t = __cache( 'timers' );

   defined $interval and $interval eq 'abs' and $after -= time;
   defined $interval and $interval =~ m{ \A (?: abs | rel ) \z }mx
       and $interval = 0;

   $after > 0 or $after = 0; my @args = (after => $after, cb => $cb);

   not defined $interval and push @args, 'interval', $after;
       defined $interval and $interval and push @args, 'interval', $interval;
   $t->{ $id } = [ $cb, AnyEvent->timer( @args ) ];
   return $t->{ $id }->[ 1 ];
}

sub stop {
   $_[ 0 ]->{cv}->send; return;
}

sub stop_timer {
   my $id = $_[ 1 ]; my $t = __cache( 'timers' ); my $cb;

   exists $t->{ $id } and $cb = $t->{ $id }->[ 0 ] and undef $t->{ $id }->[ 1 ];

   delete $t->{ $id }; return $cb;
}

sub unwatch_child {
   return delete __cache( 'watchers' )->{ $_[ 1 ] };
}

sub unwatch_read_handle {
   return delete __cache( 'handles' )->{ 'r'.$_[ 1 ] };
}

sub unwatch_signal {
   my ($self, $signal, $id) = @_;

   # Can't use grep because we have to preserve the addresses
   my $attaches = $self->_sigattaches->{ $signal } or return;

   for (my $i = 0; $i < @{ $attaches }; ) {
      not $id and splice @{ $attaches }, $i, 1, () and next;
      $id == \$attaches->[ $i ] and splice @{ $attaches }, $i, 1, () and last;
      $i++;
   }

   scalar @{ $attaches } and return;
   delete $self->_sigattaches->{ $signal };
   delete __cache( 'signals' )->{ $signal };
   return;
}

sub unwatch_write_handle {
   return delete __cache( 'handles' )->{ 'w'.$_[ 1 ] };
}

sub uuid {
   state $uuid //= 1; return $uuid++;
}

sub watch_child {
   my ($self, $id, $cb) = @_; my $w = __cache( 'watchers' );

   if ($id == 0) {
      for (sort { $a <=> $b } keys %{ $w }) {
         $w->{ $_ }->[ 0 ]->recv; undef $w->{ $_ }->[ 0 ];
         undef $w->{ $_ }->[ 1 ]; delete $w->{ $_ };
      }

      return;
   }

   my $cv = $w->{ $id }->[ 0 ] = AnyEvent->condvar;

   return   $w->{ $id }->[ 1 ] = AnyEvent->child( pid => $id, cb => sub {
      $cb->( @_ ); $cv->send } );
}

sub watch_read_handle {
   my ($self, $fh, $cb) = @_; my $h = __cache( 'handles' );

   return $h->{ "r${fh}" } = AnyEvent->io( cb => $cb, fh => $fh, poll => 'r' );
}

sub watch_signal {
   my ($self, $signal, $cb) = @_; my $attaches;

   unless ($attaches = $self->_sigattaches->{ $signal }) {
      my $s = __cache( 'signals' ); my @attaches;

      $s->{ $signal } = AnyEvent->signal( signal => $signal, cb => sub {
         for my $attachment (@attaches) { $attachment->() }
      } );

      $attaches = $self->_sigattaches->{ $signal } = \@attaches;
   }

   push @{ $attaches }, $cb; return \$attaches->[ -1 ];
}

sub watch_write_handle {
   my ($self, $fh, $cb) = @_; my $h = __cache( 'handles' );

   return $h->{ "w${fh}" } = AnyEvent->io( cb => $cb, fh => $fh, poll => 'w' );
}

# Private methods
sub _sigattaches {
   return $_[ 0 ]->{_sigattaches} ||= {};
}

# Private functions
sub __cache {
   return $_CACHE->{ $PID }->{ $_[ 0 ] } ||= {};
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

This documents version v0.2.$Rev: 17 $ of L<App::MCP::Async::Loop>

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
