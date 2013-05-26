# @(#)Ident: Loop.pm 2013-05-26 00:37 pjf ;

package App::MCP::Async::Loop;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 4 $ =~ /\d+/gmx );

use AnyEvent;
use Async::Interrupt;
use Class::Usul::Constants;
use Class::Usul::Functions qw(arg_list);
use Scalar::Util           qw(blessed);

sub new {
   my $self = shift; my $attr = arg_list( @_ );

   $attr->{cv} = AnyEvent->condvar; $attr->{handles} ||= {};

   $attr->{signals} ||= {}; $attr->{timers} ||= {}; $attr->{watchers} ||= {};

   return bless $attr, blessed $self || $self;
}

sub attach_signal {
   my ($self, $sig, $cb) = @_;

   $self->{signals}->{ $sig } = AnyEvent->signal( signal => $sig, cb => $cb );

   return;
}

sub detach_signal {
   my ($self, $sig) = @_; return delete $self->{signals}->{ $sig };
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
   my ($self, $id) = @_; return delete $self->{timers}->{ $id };
}

sub unwatch_read_handle {
   my ($self, $id) = @_; return delete $self->{handles}->{ "r${id}" };
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

sub watch_read_handle {
   my ($self, $id, $fh, $cb) = @_;

   $self->{handles}->{ "r${id}" }
      = AnyEvent->io( cb => $cb, fh => $fh, poll => 'r' );

   return;
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

This documents version v0.1.$Rev: 4 $ of L<App::MCP::Async::Loop>

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
