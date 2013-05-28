# @(#)Ident: Periodical.pm 2013-05-28 22:33 pjf ;

package App::MCP::Async::Periodical;

use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 7 $ =~ /\d+/gmx );

use App::MCP::Functions    qw(pad5z);
use Class::Usul::Moose;
use Class::Usul::Constants;
use Class::Usul::Functions qw(throw);

# Public attributes
has 'autostart'   => is => 'ro', isa => Bool, default => FALSE;

has 'builder'     => is => 'ro', isa => Object, handles => [ qw(log) ],
   required       => TRUE;

has 'code'        => is => 'ro', isa => CodeRef, required => TRUE;

has 'description' => is => 'ro', isa => NonEmptySimpleStr, required => TRUE;

has 'interval'    => is => 'ro', isa => PositiveInt, default => 1;

has 'log_key'     => is => 'ro', isa => NonEmptySimpleStr, required => TRUE;

has 'loop'        => is => 'ro', isa => Object, required => TRUE;

has 'pid'         => is => 'ro', isa => PositiveInt, required => TRUE;

# Construction
around 'BUILDARGS' => sub {
   my ($next, $self, @args) = @_; my $attr = $self->$next( @args );

   my $factory = delete $attr->{factory} or throw 'No factory';

   $attr->{builder} = $factory->builder;
   $attr->{loop   } = $factory->loop;
   $attr->{pid    } = $factory->uuid;
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
   my $self = shift; my $key = $self->log_key; my $did = pad5z $self->pid;

   $self->log->info( "${key}[${did}]: Stopping ".$self->description );
   $self->loop->stop_timer( $self->pid );
   return;
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

This documents version v0.1.$Rev: 7 $ of L<App::MCP::Async::Periodical>

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
