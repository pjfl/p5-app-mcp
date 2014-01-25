package App::MCP::Async;

use namespace::sweep;

use Moo;
use App::MCP::Async::Loop;
use App::MCP::Constants;
use App::MCP::Functions    qw( log_leader );
use Class::Usul::Functions qw( ensure_class_loaded );
use Class::Usul::Types     qw( BaseType Object );
use POSIX                  qw( WEXITSTATUS );

# Public attributes
has 'builder' => is => 'ro',   isa => BaseType,
   handles    => [ qw( log ) ], required => TRUE;

has 'loop'    => is => 'lazy', isa => Object,
   builder    => sub { App::MCP::Async::Loop->new };

# Public methods
sub new_notifier {
   my ($self, %p) = @_; my $log = $self->log;

   my $ddesc = my $desc = delete $p{desc}; my $key = delete $p{key};

   my $log_level = delete $p{log_level} || 'info'; my $type = delete $p{type};

   my $logger = sub {
      my ($level, $id, $msg) = @_; my $lead = log_leader $level, $key, $id;

      return $log->$level( $lead.$msg );
   };

   my $_on_exit = delete $p{on_exit}; my $on_exit = sub {
      my $pid = shift; my $rv = WEXITSTATUS( shift );

      $logger->( $log_level, $pid, ucfirst "${desc} stopped rv ${rv}" );

      return $_on_exit ? $_on_exit->( $pid, $rv ) : undef;
   };

   if ($type eq 'function') { $desc .= ' worker'; $ddesc = $desc.' pool' }

   my $class = (substr $type, 0, 1) eq '+'
             ? (substr $type, 1) : __PACKAGE__.'::'.(ucfirst $type);

   ensure_class_loaded( $class );

   my $notifier = $class->new( builder     => $self->builder,
                               description => $desc,
                               log_key     => $key,
                               on_exit     => $on_exit, %p, );

   $logger->( $log_level, $notifier->pid, "Started ${ddesc}" );

   return $notifier;
}

1;

__END__

=pod

=head1 Name

App::MCP::Async - <One-line description of module's purpose>

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
