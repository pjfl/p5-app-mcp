package App::MCP::Constants;

use strictures;
use parent 'Exporter::Tiny';

use App::MCP::Exception;
use Class::Usul::Cmd::Constants       ( );
use HTML::StateTable::Constants       ( );
use HTML::Forms::Constants            ( );
use Web::ComposableRequest::Constants ( );

our @EXPORT = qw( BUG_STATE_ENUM CRONTAB_FIELD_NAMES DOTS HASH_CHAR
                  LOG_KEY_WIDTH JOB_TYPE_ENUM SEPARATOR SQL_FALSE SQL_TRUE
                  STATE_ENUM TRANSITION_ENUM VARCHAR_MAX_SIZE );

Class::Usul::Cmd::Constants->Exception_Class('App::MCP::Exception');
HTML::StateTable::Constants->Exception_Class('App::MCP::Exception');
HTML::Forms::Constants->Exception_Class('App::MCP::Exception');
Web::ComposableRequest::Constants->Exception_Class('App::MCP::Exception');

my $Code_Attr = {};

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

sub HASH_CHAR () { chr 35     }
sub DOTS      () { "\x{2026}" }
sub SEPARATOR () { '/'        }

sub BUG_STATE_ENUM      () { [ qw( assigned fixed open wontfix ) ] }
sub CRONTAB_FIELD_NAMES () { qw( min hour mday mon wday ) }
sub LOG_KEY_WIDTH       () { 13 }
sub JOB_TYPE_ENUM       () { [ 'box', 'job' ] }
sub SQL_FALSE           () { \'false' } #' emacs
sub SQL_TRUE            () { \'true' } #' emacs
sub STATE_ENUM          () { [ qw( active hold failed finished
                                   inactive running starting terminated ) ] }
sub TRANSITION_ENUM     () { [ qw( activate fail finish off_hold
                                   on_hold start started terminate ) ] }
sub VARCHAR_MAX_SIZE    () { 255 }

1;

__END__

=pod

=encoding utf8

=head1 Name

App::MCP::Constants - One-line description of the modules purpose

=head1 Synopsis

   use App::MCP::Constants;
   # Brief but working code examples

=head1 Description

=head1 Configuration and Environment

Defines no attributes

=head1 Subroutines/Methods

=head2 SEPARATOR

The forward slash character. Used by L<App::MCP::MaterialisedPath>

=head1 Diagnostics

=head1 Dependencies

=over 3

=item L<Class::Usul>

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

Copyright (c) 2015 Peter Flanigan. All rights reserved

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
