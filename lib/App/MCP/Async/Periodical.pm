# @(#)Ident: Periodical.pm 2013-06-01 13:52 pjf ;

package App::MCP::Async::Periodical;

use version; our $VERSION = qv( sprintf '0.2.%d', q$Rev: 16 $ =~ /\d+/gmx );

use App::MCP::Functions     qw(log_leader);
use Class::Usul::Moose;
use Class::Usul::Constants;
use Class::Usul::Functions  qw(throw);
use Scalar::Util            qw(weaken);

extends q(App::MCP::Async::Base);

# Public attributes
has 'absolute' => is => 'ro', isa => Bool, default => FALSE;

has 'code'     => is => 'ro', isa => CodeRef, required => TRUE;

has 'interval' => is => 'ro', isa => PositiveInt, default => 1;

# Construction
sub BUILD {
   my $self = shift; $self->autostart and $self->start; return;
}

# Public methods
sub once {
   my $self = shift; weaken( $self ); my $code = sub { $self->code->( $self ) };
   my $pid  = $self->pid;

   $self->loop->watch_time( $pid, $code, $self->interval, $self->absolute );
   return;
}

sub start {
   my $self = shift; weaken( $self ); my $code = sub { $self->code->( $self ) };

   $self->loop->start_timer( $self->pid, $code, $self->interval );
   return;
}

sub stop {
   my $self = shift; my $lead = log_leader 'debug', $self->log_key, $self->pid;

   $self->log->debug( $lead.'Stopping '.$self->description );
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

This documents version v0.2.$Rev: 16 $ of L<App::MCP::Async::Periodical>

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
