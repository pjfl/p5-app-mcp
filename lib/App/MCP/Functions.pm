# @(#)Ident: Functions.pm 2013-05-30 19:04 pjf ;

package App::MCP::Functions;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 14 $ =~ /\d+/gmx );

my @_functions;

BEGIN {
   @_functions = ( qw(log_leader log_recv_error read_exactly
                      trigger_input_handler trigger_output_handler) );
}

use Class::Usul::Constants;
use Class::Usul::Functions qw(pad);
use English                qw(-no_match_vars);

use Sub::Exporter::Progressive -setup => {
   exports => [ @_functions ], groups => { default => [], },
};

# Public functions
sub log_leader ($$;$) {
   my ($level, $key, $id) = @_;

   my $dkey = __padkey( $level, $key ); my $did = __padid( $id );

   return "${dkey}[${did}]: ";
}

sub log_recv_error ($$$) {
   my ($log, $id, $red) = @_;

   unless (defined $red) {
      $log->error( log_leader( 'error', 'RECV', $id ).$OS_ERROR );
      return FAILED;
   }

   unless (length $red) {
      $log->info( log_leader( 'info', 'RECV', $id ).'EOF' ); return OK;
   }

   return;
}

sub read_exactly ($$$) {
   $_[ 1 ] = q();

   while ((my $have = length $_[ 1 ]) < $_[ 2 ]) {
      my $red = read( $_[ 0 ], $_[ 1 ], $_[ 2 ] - $have, $have );

      defined $red or return; $red or return q();
   }

   return $_[ 2 ];
}

sub trigger_input_handler (;$) {
   my $pid = shift; return $pid ? CORE::kill 'USR1', $pid : FALSE;
}

sub trigger_output_handler (;$) {
   my $pid = shift; return $pid ? CORE::kill 'USR2', $pid : FALSE;
}

# Private functions
sub __padid {
   my $id = shift; $id //= $PID; return pad $id, 5, 0, 'left';
}

sub __padkey {
   my ($level, $key) = @_; my $w = 11 - length $level; $w < 1 and $w = 1;

   return pad $key, $w, SPC, 'left';
}

1;

__END__

=pod

=encoding utf8

=head1 Name

App::MCP::Functions - One-line description of the modules purpose

=head1 Synopsis

   use App::MCP::Functions;
   # Brief but working code examples

=head1 Version

This documents version v0.1.$Rev: 14 $ of L<App::MCP::Functions>

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
