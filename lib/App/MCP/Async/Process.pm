# @(#)Ident: Process.pm 2013-05-25 12:33 pjf ;

package App::MCP::Async::Process;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 3 $ =~ /\d+/gmx );

use Class::Usul::Constants;
use Class::Usul::Functions qw(arg_list pad throw);
use English                qw(-no_match_vars);
use Scalar::Util           qw(blessed weaken);
use Storable               qw(nfreeze);

sub new {
   my $self = shift; my $attr = arg_list( @_ );

   my $factory = delete $attr->{factory}; $attr->{log} = $factory->builder->log;
   my $pipe    = delete $attr->{pipe}; $pipe and $attr->{hndl} = $pipe->[ 1 ];
   my $new     = bless  $attr, blessed $self || $self;
   my $weak    = $new; weaken( $weak );
   my $code    = sub { $new->{code}->( $weak ) };
   my $r       = $factory->builder->run_cmd( [ $code ], { async => TRUE } );

   $factory->loop->watch_child( $new->{pid} = $r->{pid}, $new->{on_exit} );

   return $new;
}

sub is_running {
   return CORE::kill 0, $_[ 0 ]->{pid};
}

sub pid {
   return $_[ 0 ]->{pid};
}

sub send {
   my ($self, @args) = @_; my $id = pad $args[ 0 ], 5, 0, 'left';

   my $hndl  = $self->{hndl}
               or throw error => 'Process [_1] has no handle', args => [ $id ];
   my $rec   = nfreeze [ @args ];
   my $bytes = pack( 'I', length $rec ).$rec;
   my $len   = $hndl->syswrite( $bytes, length $bytes );

   defined $len or $self->{log}->error( " SEND[${id}]: ${OS_ERROR}" );

   return;
}

sub stop {
   my $self = shift; $self->is_running or return;

   my $desc = $self->{description};
   my $key  = $self->{log_key};
   my $pid  = $self->{pid};
   my $did  = pad $pid, 5, 0, 'left';

   $self->{log}->info( "${key}[${did}]: Stopping ${desc}" );
   CORE::kill 'TERM', $pid;
   return;
}

1;

__END__

=pod

=encoding utf8

=head1 Name

App::MCP::Async::Process - One-line description of the modules purpose

=head1 Synopsis

   use App::MCP::Async::Process;
   # Brief but working code examples

=head1 Version

This documents version v0.1.$Rev: 3 $ of L<App::MCP::Async::Process>

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
