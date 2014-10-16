package App::MCP::Functions;

use strictures;
use parent 'Exporter::Tiny';

use App::MCP::Constants    qw( FAILED FALSE LANG NUL OK SPC TRUE );
use Class::Usul::Functions qw( pad split_on__ throw );
use English                qw( -no_match_vars );
use Storable               qw( nfreeze );

our @EXPORT_OK = ( qw( env_var extract_lang get_hashed_pw get_salt
                       log_leader qualify_job_name terminate
                       trigger_input_handler trigger_output_handler ) );

# Public functions
sub env_var ($;$) {
   defined $_[ 1 ] and $ENV{ 'MCP_'.$_[ 0 ] } = $_[ 1 ];

   return $ENV{ 'MCP_'.$_[ 0 ] };
}

sub extract_lang ($) {
   return $_[ 0 ] ? (split_on__ $_[ 0 ])[ 0 ] : LANG;
}

sub get_hashed_pw ($) {
   my @parts = split m{ [\$] }mx, $_[ 0 ]; return substr $parts[ -1 ], 22;
}

sub get_salt ($) {
   my @parts = split m{ [\$] }mx, $_[ 0 ];

   $parts[ -1 ] = substr $parts[ -1 ], 0, 22;

   return join '$', @parts;
}

sub log_leader ($$;$) {
   my $dkey = __padkey( $_[ 0 ], $_[ 1 ] ); my $did = __padid( $_[ 2 ] );

   return "${dkey}[${did}]: ";
}

sub qualify_job_name (;$$) {
   my ($name, $ns) = @_; $ns //= 'Main'; my $sep = '::'; $name //= 'void';

   return $name =~ m{ $sep }mx ? $name : "${ns}${sep}${name}";
}

sub terminate ($) {
   $_[ 0 ]->unwatch_signal( 'QUIT' ); $_[ 0 ]->unwatch_signal( 'TERM' );
   $_[ 0 ]->stop;
   return TRUE;
}

sub trigger_input_handler ($) {
   return $_[ 0 ] ? CORE::kill 'USR1', $_[ 0 ] : FALSE;
}

sub trigger_output_handler ($) {
   return $_[ 0 ] ? CORE::kill 'USR2', $_[ 0 ] : FALSE;
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
