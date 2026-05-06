package App::MCP::Constants;

use strictures;
use parent 'Exporter::Tiny';

use App::MCP::Exception;
use Class::Usul::Cmd::Constants       ( );
use HTML::StateTable::Constants       ( );
use HTML::Forms::Constants            ( );
use Web::ComposableRequest::Constants ( );

my $exception_class = 'App::MCP::Exception';

Class::Usul::Cmd::Constants->Exception_Class($exception_class);
HTML::StateTable::Constants->Exception_Class($exception_class);
HTML::Forms::Constants->Exception_Class($exception_class);
Web::ComposableRequest::Constants->Exception_Class($exception_class);

our @EXPORT = qw( CRONTAB_FIELD_NAMES DOTS HASH_CHAR LOG_KEY_WIDTH
                  JOB_TYPE_ENUM SEPARATOR SQL_FALSE SQL_NOW SQL_TRUE STATE_ENUM
                  TRANSITION_ENUM VARCHAR_MAX_SIZE );

=pod

=encoding utf8

=head1 Name

App::MCP::Constants - Application constants

=head1 Synopsis

   use App::MCP::Constants;

=head1 Description

Application constants

=head1 Configuration and Environment

Defines no attributes

=head1 Subroutines/Methods

Exports the following methods;

=over 3

=item C<import>

Handles the importing of locally defined constants. Hands any others off to
the L<parent|Class::Usul::Cmd::Constants> class

=cut

sub import {
   my $class       = shift;
   my $global_opts = { $_[0] && ref $_[0] eq 'HASH' ? %{+ shift } : () };
   my @wanted      = @_;
   my $usul_const  = {}; $usul_const->{$_} = 1 for (@wanted);
   my @self        = ();

   for (@EXPORT) { push @self, $_ if delete $usul_const->{$_} }

   $global_opts->{into} ||= caller;
   Class::Usul::Cmd::Constants->import($global_opts, keys %{$usul_const});
   $class->SUPER::import($global_opts, @self);
   return;
}

=back

Exports the following constants;

=over 3

=item C<HASH_CHAR>

=cut

sub HASH_CHAR () { chr 35 }

=item C<DOTS>

=cut

sub DOTS () { "\x{2026}" }

=item C<SEPARATOR>

The forward slash character. Used by the L<materialised
path|App::MCP::MaterialisedPath> role

=cut

sub SEPARATOR () { '/' }

=item C<CRONTAB_FIELD_NAMES>

=cut

sub CRONTAB_FIELD_NAMES () { qw( min hour mday mon wday ) }

=item C<LOG_KEY_WIDTH>

=cut

sub LOG_KEY_WIDTH () { 13 }

=item C<JOB_TYPE_ENUM>

=cut

sub JOB_TYPE_ENUM () { [ 'box', 'job' ] }

=item C<SQL_FALSE>

=cut

sub SQL_FALSE () { \q{false} }

=item C<SQL_NOW>

=cut

sub SQL_NOW () { \q{NOW()} }

=item C<SQL_TRUE>

=cut

sub SQL_TRUE () { \q{true} }

=item C<STATE_ENUM>

=cut

sub STATE_ENUM () { [ qw( active hold failed finished inactive running
                          starting terminated unknown ) ] }
=item C<TRANSITION_ENUM>

=cut

sub TRANSITION_ENUM () { [ qw( activate deactivate fail finish off_hold
                               on_hold start started terminate ) ] }
=item C<VARCHAR_MAX_SIZE>

=cut

sub VARCHAR_MAX_SIZE () { 255 }

1;

__END__

=back

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Class::Usul::Cmd::Constants>

=item L<Exporter::Tiny>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module. Please report problems to
http://rt.cpan.org/NoAuth/Bugs.html?Dist=App-MCP.
Patches are welcome

=head1 Acknowledgements

Larry Wall - For the Perl programming language

=head1 Author

Peter Flanigan, C<< <pjfl@cpan.org> >>

=head1 License and Copyright

Copyright (c) 2025 Peter Flanigan. All rights reserved

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
