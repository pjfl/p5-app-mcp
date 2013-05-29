# @(#)Ident: Periodical.pm 2013-05-29 20:39 pjf ;

package App::MCP::Async::Periodical;

use version; our $VERSION = qv( sprintf '0.2.%d', q$Rev: 10 $ =~ /\d+/gmx );

use App::MCP::Functions     qw(padid padkey);
use Class::Usul::Moose;
use Class::Usul::Constants;
use Class::Usul::Functions  qw(throw);

extends q(App::MCP::Async::Base);

# Public attributes
has 'code'     => is => 'ro', isa => CodeRef, required => TRUE;

has 'interval' => is => 'ro', isa => PositiveInt, default => 1;

# Construction
around 'BUILDARGS' => sub {
   my ($next, $self, @args) = @_; my $attr = $self->$next( @args );

   my $factory = delete $attr->{factory} or throw 'No factory';

   $attr->{builder} = $factory->builder;
   $attr->{loop   } = $factory->loop;
   return $attr;
};

sub BUILD {
   my $self = shift; $self->autostart and $self->start; return;
}

# Public methods
sub start {
   my $self = shift;

   $self->loop->start_timer( $self->pid, $self->code, $self->interval );
   return;
}

sub stop {
   my $self = shift;
   my $dkey = padkey 'info', $self->log_key; my $did = padid $self->pid;

   $self->log->info( "${dkey}[${did}]: Stopping ".$self->description );
   $self->loop->stop_timer( $self->pid );
   return;
}

# Private methdods
sub _build_pid {
   return $_[ 0 ]->loop->uuid;
}

1;

__END__

=pod

=encoding utf8

=head1 Name

App::MCP::Async::Periodical - One-line description of the modules purpose

=head1 Synopsis

   use App::MCP::Async::Periodical;
   # Brief but working code examples

=head1 Version

This documents version v0.2.$Rev: 10 $ of L<App::MCP::Async::Periodical>

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
