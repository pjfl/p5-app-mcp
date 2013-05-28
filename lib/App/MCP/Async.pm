# @(#)$Ident: Async.pm 2013-05-27 20:03 pjf ;

package App::MCP::Async;

use feature                 qw(state);
use version; our $VERSION = qv( sprintf '0.2.%d', q$Rev: 6 $ =~ /\d+/gmx );

use App::MCP::Functions     qw(pad5z);
use Class::Usul::Moose;
use Class::Usul::Constants;
use Class::Usul::Functions  qw(throw);
use POSIX                   qw(WEXITSTATUS);

use App::MCP::Async::Loop;
use App::MCP::Async::Process;
use App::MCP::Async::Function;
use App::MCP::Async::Periodical;
use App::MCP::Async::Routine;

has 'builder' => is => 'ro',   isa => Object, weak_ref => TRUE;

has 'loop'    => is => 'lazy', isa => Object, default  => sub {
   App::MCP::Async::Loop->new( log => $_[ 0 ]->builder->log ) };

sub new_notifier {
   my ($self, %p) = @_; my $log = $self->builder->log; my $notifier;

   my $code = $p{code}; my $desc = $p{desc}; my $key = $p{key};

   my $logger = sub {
      my ($level, $pid, $msg) = @_; my $did = pad5z $pid;

      $log->$level( "${key}[${did}]: ${msg}" ); return;
   };

   my $on_exit = sub {
      my $pid = shift; my $rv = WEXITSTATUS( shift );

      $logger->( 'info', $pid, ucfirst "${desc} stopped ${rv}" ); return;
   };

   if ($p{type} eq 'function') {
      $notifier = App::MCP::Async::Function->new
         (  code        => $code,
            description => $desc,
            factory     => $self,
            log_key     => $key,
            max_calls   => $p{max_calls},
            max_workers => $p{max_workers},
            on_exit     => $on_exit, );
   }
   elsif ($p{type} eq 'periodical') {
      $notifier = App::MCP::Async::Periodical->new
         (  autostart   => TRUE,
            code        => $code,
            description => $desc,
            factory     => $self,
            log_key     => $key,
            interval    => $p{interval} );
   }
   elsif ($p{type} eq 'process') {
      $notifier = App::MCP::Async::Process->new
         (  code        => $code,
            description => $desc,
            factory     => $self,
            log_key     => $key,
            on_exit     => $on_exit, );
   }
   elsif ($p{type} eq 'routine') {
      $notifier = App::MCP::Async::Routine->new
         (  code        => $code,
            description => $desc,
            factory     => $self,
            log_key     => $key,
            on_exit     => $on_exit, );
   }
   else { throw error => 'Notifier [_1] type unknown', args => [ $p{type} ] }

   $logger->( 'info', $notifier->pid, "Started ${desc}" );

   return $notifier;
}

sub uuid {
   state $uuid //= 0; return $uuid++;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=head1 Name

App::MCP::Async - <One-line description of module's purpose>

=head1 Version

This documents version v0.2.$Rev: 6 $

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
