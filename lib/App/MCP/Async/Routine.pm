package App::MCP::Async::Routine;

use namespace::autoclean;

use Moo;
use App::MCP::Constants qw( FALSE TRUE );
use App::MCP::Functions qw( log_leader gen_semaphore_key );
use Class::Usul::Types  qw( Bool NonZeroPositiveInt Object );
use IPC::SysV           qw( IPC_CREAT S_IRUSR S_IWUSR );
use IPC::Semaphore;

extends q(App::MCP::Async::Process);

has 'execute'       => is => 'ro',   isa => Bool, default => FALSE;

has 'is_parent'     => is => 'ro',   isa => Bool, default => TRUE;

has 'semaphore_key' => is => 'lazy', isa => NonZeroPositiveInt,
   init_arg         => 'semkey', required => TRUE;

# Private attributes
has '_semaphore'    => is => 'lazy', isa => Object, reader => 'semaphore',
   builder          => sub {
      my $self = shift;
      my $key  = $self->semaphore_key;
      my @args = $self->is_parent ? (2, S_IRUSR | S_IWUSR | IPC_CREAT) : (0, 0);
      my $s    = IPC::Semaphore->new( $key, @args );

      if ($self->is_parent) {
         $s->setval( 0, TRUE ); $s->setval( 1, $self->autostart );
      }

      return $s;
   };

# Construction
around 'BUILDARGS' => sub {
   my ($orig, $self, @args) = @_; my $attr = $orig->( $self, @args );

   $attr->{semkey} and $attr->{is_parent} = FALSE;
   $attr->{semkey} or  $attr->{semkey   } = gen_semaphore_key $attr->{log_key};
   $attr->{code  } =   $attr->{execute  } ? $attr->{code}->( $attr->{semkey} )
                                          : __loop_while_waiting( $attr );
   return $attr;
};

before 'BUILD' => sub {
   $_[ 0 ]->semaphore; # Trigger lazy build before process fork
};

after 'BUILD' => sub {
   my $self      = shift;
   my $sem_key   = sprintf '%x', $self->semaphore_key;
   my $lead      = log_leader 'debug', $self->log_key, $self->pid;
   my $id        = $self->semaphore->id;
   my $is_parent = $self->is_parent;

   $self->log->debug( "${lead}Semaphore key ${sem_key} ${id} ${is_parent}" );
   return;
};

around 'is_running' => sub {
   my ($orig, $self) = @_;

   return $self->execute ? $orig->( $self ) : $self->semaphore->getval( 0 );
};

around 'stop' => sub {
   my ($orig, $self) = @_;

   $self->execute and return $orig->( $self ); $self->is_running or return;

   my $lead = log_leader 'debug', $self->log_key, $self->pid;

   $self->log->debug( $lead.'Stopping '.$self->description );
   $self->semaphore->setval( 0, FALSE );
   $self->trigger;
   return;
};

sub DEMOLISH {
   $_[ 0 ]->is_parent and defined $_[ 0 ]->semaphore
                      and $_[ 0 ]->semaphore->remove;
   return;
}

# Public methods
sub await_trigger {
   $_[ 0 ]->semaphore->op( 1, -1, 0 ); return;
}

sub start {
   $_[ 0 ]->semaphore->setval( 0, TRUE ); return;
}

sub trigger {
   my $self = shift; my $semaphore = $self->semaphore or return;

   my $val = $semaphore->getval( 1 ) // 0;

   $val < 1 and $semaphore->op( 1, 1, 0 );
   return;
}

# Private functions
sub __loop_while_waiting {
   my $attr = shift; my $code = delete $attr->{code};

   my $before = delete $attr->{before}; my $after = delete $attr->{after};

   return sub {
      my $self = shift; $before and $before->( $self );

      while (TRUE) {
         $self->await_trigger; $self->is_running or last; $code->( $self );
      }

      $after and $after->( $self );
      return;
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
