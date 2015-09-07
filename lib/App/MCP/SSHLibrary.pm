package App::MCP::SSHLibrary;

use strictures;

use IPC::PerlSSH::Library;

init q{
   use lib;
   use English               qw( -no_match_vars );
   use File::Path            qw( mkpath remove_tree );
   use File::Spec::Functions qw( catdir catfile );

   sub config {
      my $appclass =  shift;
     (my $prefix   =  lc $appclass) =~ s{ :: }{_}gmsx;
      my $self     =  {
         home      => exists $ENV{HOME} && defined $ENV{HOME} && -d $ENV{HOME}
                           ? $ENV{HOME} : (getpwuid $UID)[ 7 ],
         prefix    => $prefix,
      };

      $self->{appldir} = catdir ( $self->{home   }, ".${prefix}" );
      $self->{logsdir} = catdir ( $self->{appldir}, 'logs' );
      $self->{tempdir} = catdir ( $self->{appldir}, 'tmp'  );
      $self->{cfgfile} = catfile( $self->{appldir}, "${prefix}.json" );
      return $self;
   }

   sub local_lib {
      my $appclass  = shift;
      my $config    = config( $appclass );
      my $local_lib = catdir( $config->{home}, 'perl5' );
      my $perl_lib  = catdir( $local_lib, 'lib', 'perl5' );

      -d $perl_lib or return; lib->import( $perl_lib );
      eval { require local::lib };
      $EVAL_ERROR or local::lib->setup_local_lib_for( $local_lib );
      return;
   }
};

func 'dispatch' => q{
   my $args     = { @_ };
   my $appclass = $args->{appclass} or die 'No appclass';
   my $worker   = $args->{worker  } or die 'No worker class';

   local_lib( $appclass );
   eval "require ${worker}"; $EVAL_ERROR and die $EVAL_ERROR;
   return $worker->new( $args )->dispatch;
};

func 'distclean' => q{
   require File::Copy;

   my $appclass = shift;  $appclass or die 'No appclass';
   my $config   = config( $appclass ); my $tempdir = $config->{tempdir};

   chdir $tempdir or die "Directory ${tempdir} cannot chdir: ${OS_ERROR}";

   my @list     = glob( '*.tar.gz' );

   for (@list) { unlink $_; s{ \.tar\.gz \z }{}mx; -e $_ and remove_tree( $_ ) }

   my $build    = catdir( $config->{home}, '.cpanm' );

   chdir $build or die "Directory ${build} cannot chdir: ${OS_ERROR}";

   -e 'build.log'    and File::Copy::copy( 'build.log', 'last-build.log' );
   -e 'build.log'    and unlink 'build.log';
   -e 'latest-build' and unlink 'latest-build';
   -d 'work'         and remove_tree( 'work' );
   return 'Installation cleaned';
};

func 'install_cpan_minus' => q{
   require Archive::Tar;

   my $appclass = shift;   $appclass or die 'No appclass';
   my $file     = shift;   $file     or die 'No filename';
   my $config   = config ( $appclass ); chdir $config->{tempdir};
   my $path     = catfile( $config->{tempdir}, $file );
   -f $path    or die "File ${path} not found";
   my $tar      = Archive::Tar->new; $tar->read( $path ); $tar->extract;
      $path     =~ s{ \.tar\.gz \z }{}mx;
   -e $path    or die "Path ${path} not found";
   my $cmd      = "${EXECUTABLE_NAME} ${path} App::cpanminus";
   my $cpanm    = catfile( $config->{home}, 'perl5', 'bin', 'cpanm' );

   chdir $config->{home}; qx( $cmd ); -x $cpanm or die 'No cpanm';
   return 'Installed cpanm';
};

func 'install_distribution' => q{
   my $appclass = shift;   $appclass or die 'No appclass';
   my $file     = shift;   $file     or die 'No filename';
   my $config   = config ( $appclass ); chdir $config->{home};
   my $path     = $file !~ m{ \A [a-zA-Z0-9_]+ : }mx
                ? catfile( $config->{tempdir}, $file ) : $file;
   my $base     = catfile( $config->{home}, 'perl5' );
   my $cpanm    = catfile( $base, 'bin', 'cpanm' );
   my $cmd      = "${cpanm} -l ${base} --notest ${path}"; qx( $cmd );
  (my $dist     = $file) =~ s{ \.tar\.gz \z }{}mx;

   return "Installed ${dist}";
};

func 'provision' => q{
   my $appclass = shift;  $appclass or die 'No appclass';
   my $worker   = shift;
   my $config   = config( $appclass );
     ($config->{home   } and -d $config->{home}) or die 'No home';
   -d $config->{appldir} or  mkpath( $config->{appldir}, { mode => 0750 } );
   -d $config->{logsdir} or  mkpath( $config->{logsdir}, { mode => 0750 } );
   -d $config->{tempdir} or  mkpath( $config->{tempdir}, { mode => 0750 } );
   my $cfgfile  = $config->{cfgfile};

   unless (-f $cfgfile) {
      my $conf  = "{\n   \"name\" : \"worker\"\n}\n";
      open( my $fh, '>', $cfgfile ) or die "Path ${cfgfile} cannot open - $!";
      print $fh $conf or die "Path ${cfgfile} cannot write - $!"; close $fh;
      chmod 0640, $cfgfile or die "Path ${cfgfile} cannot chmod - $!";
   }

   $worker or return; local_lib( $appclass ); eval "require ${worker}";

   return $EVAL_ERROR ? "${EVAL_ERROR}"
                      : sprintf 'version=%s', $worker->VERSION;
};

func 'remote_env' => q{
   my $appclass = shift; $appclass or die 'No appclass'; local_lib( $appclass );

   return join "\n", map { "${_}=".$ENV{ $_ } } keys %ENV;
};

func 'writefile' => q{
   my $appclass = shift; $appclass or die 'No appclass';
   my $file     = shift; $file     or die 'No filename';
   my $path     = catfile( config( $appclass )->{tempdir}, $file );

   open( my $fh, '>', $path ) or die "Path ${path} cannot open - ${OS_ERROR}";
   print $fh $_[ 0 ] or die "Path ${path} cannot write - $OS_ERROR"; close $fh;
   return "Wrote ${file} length ".(-s $path);
};

1;

__END__

=pod

=head1 Name

App::MCP::SSHLibrary - <One-line description of module's purpose>

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
