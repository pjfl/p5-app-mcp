package App::MCP::Functions;

use strict;
use warnings;
use parent 'Exporter::Tiny';

use App::MCP::Constants;
use Class::Usul::Functions qw( pad throw );
use English                qw( -no_match_vars );
use Unexpected::Functions  qw( Unspecified );

our @EXPORT_OK = ( qw( get_or_throw get_salt log_leader qualify_job_name
                       read_exactly recv_arg_error recv_rv_error
                       trigger_input_handler trigger_output_handler ) );

# Public functions
sub get_or_throw ($$) {
   my ($params, $name) = @_;

   defined (my $param = $params->{ $name })
      or throw class => Unspecified, args => [ $name ];

   return $param;
}

sub get_salt ($) {
   my $password = shift; my @parts = split m{ [\$] }mx, $password;

   $parts[ -1 ] = substr $parts[ -1 ], 0, 22;

   return join '$', @parts;
}

sub log_leader ($$;$) {
   my ($level, $key, $id) = @_;

   my $dkey = __padkey( $level, $key ); my $did = __padid( $id );

   return "${dkey}[${did}]: ";
}

sub qualify_job_name (;$$) {
   my ($name, $ns) = @_; my $sep = '::'; $name //= 'void'; $ns //= 'Main';

   return $name =~ m{ $sep }mx ? $name : "${ns}${sep}${name}";
}

sub read_exactly ($$$) {
   $_[ 1 ] = q();

   while ((my $have = length $_[ 1 ]) < $_[ 2 ]) {
      my $red = read( $_[ 0 ], $_[ 1 ], $_[ 2 ] - $have, $have );

      defined $red or return; $red or return NUL;
   }

   return $_[ 2 ];
}

sub recv_arg_error ($$$) {
   my ($log, $id, $red) = @_; return __recv_error( $log, 'RCVARG', $id, $red );
}

sub recv_rv_error ($$$) {
   my ($log, $id, $red) = @_; return __recv_error( $log, 'RECVRV', $id, $red );
}

sub trigger_input_handler ($) {
   my $pid = shift; return $pid ? CORE::kill 'USR1', $pid : FALSE;
}

sub trigger_output_handler ($) {
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

sub __recv_error {
   my ($log, $key, $id, $red) = @_;

   unless (defined $red) {
      $log->error( log_leader( 'error', $key, $id ).$OS_ERROR ); return FAILED;
   }

   unless (length $red) {
      $log->info( log_leader( 'info', $key, $id ).'EOF' ); return OK;
   }

   return;
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
