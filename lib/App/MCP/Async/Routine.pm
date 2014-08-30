package App::MCP::Async::Routine;

use namespace::autoclean;

use Moo;
use App::MCP::Async::Process;
use App::MCP::Functions    qw( nonblocking_write_pipe_pair
                               read_exactly recv_arg_error );
use App::MCP::Constants    qw( FALSE TRUE );
use App::MCP::Functions    qw( log_leader );
use Class::Usul::Functions qw( bson64id );
use Class::Usul::Types     qw( Bool HashRef Object );
use English                qw( -no_match_vars );
use Storable               qw( thaw );
use Try::Tiny;

extends q(App::MCP::Async::Base);

has 'child'      => is => 'lazy', isa => Object,  builder => sub {
   App::MCP::Async::Process->new( $_[ 0 ]->child_args ) };

has 'child_args' => is => 'lazy', isa => HashRef, default => sub { {} };

has 'is_running' => is => 'rwp',  isa => Bool, default => TRUE;

# Construction
around 'BUILDARGS' => sub {
   my ($orig, $self, @args) = @_; my $args = $orig->( $self, @args ); my $attr;

   for my $k ( qw( builder description log_key ) ) {
      $attr->{ $k } = $args->{ $k };
   }

   for my $k ( qw( autostart ) ) {
      my $v = delete $args->{ $k }; defined $v and $attr->{ $k } = $v;
   }

   $args->{call_pipe } = nonblocking_write_pipe_pair;
   $args->{code      } = __call_handler( $args );
   $attr->{child_args} = $args;
   return $attr;
};

# Public methods
sub stop {
   my $self = shift; $self->_set_is_running( FALSE );

   my $pid  = $self->child->pid; $self->child->stop;

   $self->loop->watch_child( 0, sub { $pid } ); return;
}

sub call {
   my ($self, @args) = @_; $self->is_running or return FALSE;

   $args[ 0 ] ||= bson64id; return $self->child->send( @args );
}

# Private methods
sub _build_pid {
   return $_[ 0 ]->child->pid;
}

# Private functions
sub __call_handler {
   my $args   = shift;
   my $code   = $args->{code};
   my $before = delete $args->{before};
   my $reader = $args->{call_pipe}->[ 0 ];

   return sub {
      my $self = shift; my $lead = log_leader 'error', 'EXCODE', $PID;

      my $log  = $self->log; $before and $before->( $self );

      while (TRUE) {
         my $args = undef; my $rv = undef;

         if ($reader) {
            my $red = read_exactly( $reader, my $lenbuffer, 4 );

            defined ($rv = recv_arg_error( $log, $PID, $red )) and last;
            $red = read_exactly( $reader, $args, unpack( 'I', $lenbuffer ) );
            defined ($rv = recv_arg_error( $log, $PID, $red )) and last;
         }

         try {
            $args = $args ? thaw $args : [ $PID, {} ];
            $rv   = $code->( @{ $args } );
         }
         catch { $log->error( $lead.$_ ) };
      }

      return;
   }
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
