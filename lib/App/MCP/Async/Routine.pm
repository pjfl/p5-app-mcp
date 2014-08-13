package App::MCP::Async::Routine;

use namespace::autoclean;

use Moo;
use App::MCP::Constants qw( FALSE TRUE );
use App::MCP::Functions qw( log_leader );
use Class::Usul::Types  qw( Object );
use IPC::SysV           qw( IPC_CREAT S_IRUSR S_IWUSR );
use IPC::Semaphore;

extends q(App::MCP::Async::Process);

# Private attributes
has '_semaphore' => is => 'lazy', isa => Object, reader => 'semaphore';

# Construction
around 'BUILDARGS' => sub {
   my ($next, $self, @args) = @_; my $attr = $self->$next( @args );

   $attr->{code} = __loop_while_running( $attr->{code}, delete $attr->{after} );

   return $attr;
};

before 'BUILD' => sub {
   $_[ 0 ]->semaphore; # Trigger lazy build before process fork
};

sub DEMOLISH {
   defined $_[ 0 ]->semaphore and $_[ 0 ]->semaphore->remove; return;
}

# Public methods
sub is_running {
   return $_[ 0 ]->semaphore->getval( 0 );
}

sub start {
   $_[ 0 ]->semaphore->setval( 0, TRUE ); return;
}

sub stop {
   my $self = shift; $self->is_running or return;

   my $lead = log_leader 'debug', $self->log_key, $self->pid;

   $self->log->debug( $lead.'Stopping '.$self->description );
   $self->semaphore->setval( 0, FALSE );
   $self->trigger;
   return;
}

sub trigger {
   my $self = shift; my $semaphore = $self->semaphore or return;

   my $val = $semaphore->getval( 1 ) // 0;

   $val < 1 and $semaphore->op( 1, 1, 0 );
   return;
}

# Private methods
sub _await_trigger {
   $_[ 0 ]->semaphore->op( 1, -1, 0 ); return;
}

sub _build__semaphore {
   my $self = shift;
   my $id   = 1234 + $self->loop->uuid;
   my $s    = IPC::Semaphore->new( $id, 2, S_IRUSR | S_IWUSR | IPC_CREAT );

   $s->setval( 0, TRUE ); $s->setval( 1, $self->autostart );
   return $s;
}

# Private functions
sub __loop_while_running {
   my ($code, $after) = @_;

   return sub {
      my $self = shift; my $rv;

      while (TRUE) {
         $self->_await_trigger; $self->is_running or last; $rv = $code->();
      }

      $after and $after->();
      return $rv;
   };
}

1;

__END__

=pod

=encoding utf8

=head1 Name

App::MCP::Async::Routine - One-line description of the modules purpose

=head1 Synopsis

   use App::MCP::Async::Routine;
   # Brief but working code examples

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
