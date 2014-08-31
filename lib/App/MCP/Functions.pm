package App::MCP::Functions;

use strictures;
use parent 'Exporter::Tiny';

use App::MCP::Constants    qw( FAILED FALSE LANG NUL OK SPC TRUE );
use Class::Usul::Functions qw( pad split_on__ throw );
use English                qw( -no_match_vars );
use Fcntl                  qw( F_SETFL O_NONBLOCK );
use Storable               qw( nfreeze );

our @EXPORT_OK = ( qw( env_var extract_lang get_hashed_pw get_salt
                       log_leader nonblocking_write_pipe_pair
                       qualify_job_name read_exactly recv_arg_error
                       recv_rv_error send_msg terminate
                       trigger_input_handler trigger_output_handler ) );

# Public functions
sub env_var ($;$) {
   my ($k, $v) = @_; return $v ? $ENV{ "MCP_${k}" } = $v : $ENV{ "MCP_${k}" };
}

sub extract_lang ($) {
   my $v = shift; return $v ? (split_on__ $v)[ 0 ] : LANG;
}

sub get_hashed_pw ($) {
   my $crypted = shift; my @parts = split m{ [\$] }mx, $crypted;

   return substr $parts[ -1 ], 22;
}

sub get_salt ($) {
   my $crypted = shift; my @parts = split m{ [\$] }mx, $crypted;

   $parts[ -1 ] = substr $parts[ -1 ], 0, 22;

   return join '$', @parts;
}

sub log_leader ($$;$) {
   my ($level, $key, $id) = @_;

   my $dkey = __padkey( $level, $key ); my $did = __padid( $id );

   return "${dkey}[${did}]: ";
}

sub nonblocking_write_pipe_pair () {
   my ($r, $w); pipe $r, $w or throw 'No pipe';

   fcntl $w, F_SETFL, O_NONBLOCK; $w->autoflush( TRUE );

   binmode $r; binmode $w;

   return [ $r, $w ];
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
   my $log = shift; return __recv_hndlr( $log, 'RCVARG', @_ );
}

sub recv_rv_error ($$$) {
   my $log = shift; return __recv_hndlr( $log, 'RECVRV', @_ );
}

sub send_msg ($$$;@) {
   my ($writer, $log, $key, @args) = @_; $args[ 0 ] ||= $PID;

   $writer or throw error => 'Process [_1] no writer', args  => [ $args[ 0 ] ];

   my $rec = nfreeze [ @args ];
   my $buf = pack( 'I', length $rec ).$rec;
   my $len = $writer->syswrite( $buf, length $buf );

   defined $len or $log->error
      ( (log_leader 'error', $key, $args[ 0 ]).$OS_ERROR );

   return TRUE;
}

sub terminate ($) {
   my $loop = shift;

   $loop->unwatch_signal( 'QUIT' ); $loop->unwatch_signal( 'TERM' );
   $loop->stop;
   return TRUE;
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

sub __recv_hndlr {
   my ($log, $key, $id, $red) = @_;

   unless (defined $red) {
      $log->error( log_leader( 'error', $key, $id ).$OS_ERROR ); return TRUE;
   }

   unless (length $red) {
      $log->info( log_leader( 'info', $key, $id ).'EOF' ); return TRUE;
   }

   return FALSE;
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
