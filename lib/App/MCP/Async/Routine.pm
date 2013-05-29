# @(#)Ident: Routine.pm 2013-05-29 14:32 pjf ;

package App::MCP::Async::Routine;

use version; our $VERSION = qv( sprintf '0.2.%d', q$Rev: 8 $ =~ /\d+/gmx );

use App::MCP::Functions    qw(pad5z);
use Class::Usul::Moose;
use Class::Usul::Constants;
use IPC::SysV              qw(IPC_PRIVATE S_IRUSR S_IWUSR IPC_CREAT);
use IPC::Semaphore;

extends q(App::MCP::Async::Process);

# Public attributes
has 'semaphore' => is => 'ro', isa => Object, required => TRUE;

# Construction
around 'BUILDARGS' => sub {
   my ($next, $self, @args) = @_; my $attr = $self->$next( @args );

   my $id = 1234 + $attr->{factory}->loop->uuid;
   my $s  = IPC::Semaphore->new( $id, 2, S_IRUSR | S_IWUSR | IPC_CREAT );

   $attr->{semaphore} = $s; $s->setval( 0, TRUE ); $s->setval( 1, FALSE );

   return $attr;
};

sub DEMOLISH {
   defined $_[ 0 ]->semaphore and $_[ 0 ]->semaphore->remove; return;
}

# Public methods
sub await_trigger {
   $_[ 0 ]->semaphore->op( 1, -1, 0 ); return TRUE;
}

sub still_running {
   return $_[ 0 ]->semaphore->getval( 0 );
}

sub stop {
   my $self = shift; $self->is_running or return;

   my $key  = $self->log_key; my $did = pad5z $self->pid;

   $self->log->info( "${key}[${did}]: Stopping ".$self->description );
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

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=encoding utf8

=head1 Name

App::MCP::Async::Routine - One-line description of the modules purpose

=head1 Synopsis

   use App::MCP::Async::Routine;
   # Brief but working code examples

=head1 Version

This documents version v0.2.$Rev: 8 $ of L<App::MCP::Async::Routine>

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
