# @(#)$Ident: SSHLibrary.pm 2013-06-24 19:56 pjf ;

package App::MCP::SSHLibrary;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.2.%d', q$Rev: 21 $ =~ /\d+/gmx );

use IPC::PerlSSH::Library;

init q{
   use File::Path            qw( mkpath );
   use File::Spec::Functions qw( catdir catfile );
};

func 'dispatch'  => q{
   require App::MCP::Worker; return App::MCP::Worker->new( @_ )->dispatch;
};

func 'provision' => q{
   my $appclass  =  shift; $appclass or die 'No appclass';
  (my $prefix    =  lc $appclass) =~ s{ :: }{_}gmsx;
   my $home      =  exists $ENV{HOME} && defined $ENV{HOME} && -d $ENV{HOME}
                 ?  $ENV{HOME} : (getpwuid $<)[ 7 ];
     ($home and -d  $home) or die 'No home';
   my $appldir   =  catdir ( $home,    ".${prefix}" );
   -d $appldir  or  mkpath ( $appldir, { mode => 0750 } );
   my $logsdir   =  catdir ( $appldir, 'logs' );
   -d $logsdir  or  mkpath ( $logsdir, { mode => 0750 } );
   my $tempdir   =  catdir ( $appldir, 'tmp' );
   -d $tempdir  or  mkpath ( $tempdir, { mode => 0750 } );
   my $cfgfile   =  catfile( $appldir, "${prefix}.json" );

   unless (-f $cfgfile) {
      my $config =  "{\n   \"name\" : \"worker\"\n}\n";

      open( my $fh, '>', $cfgfile ) or die "Path ${cfgfile} cannot open - $!";
      print $fh $config or die "Path ${cfgfile} cannot write - $!"; close $fh;
      chmod 0640, $cfgfile or die "Path ${cfgfile} cannot chmod - $!";
   }

   eval { require App::MCP::Worker; 1; } and return "Provisioned ${appldir}";

   return "Provisioned ${appldir} - App::MCP::Worker missing";
};

1;

__END__

# TODO: Add provisioning of App::MCP::Worker and it's dependents

=pod

=head1 Name

App::MCP::SSHLibrary - <One-line description of module's purpose>

=head1 Version

This documents version v0.2.$Rev: 21 $

=head1 Synopsis

   use App::MCP::SSHLibrary;
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
