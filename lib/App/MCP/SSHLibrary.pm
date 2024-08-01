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

      return unless -d $perl_lib;
      lib->import( $perl_lib );
      eval { require local::lib };
      local::lib->setup_local_lib_for( $local_lib ) unless $EVAL_ERROR;
      return;
   }
};

func 'dispatch' => q{
   my $args     = { @_ };
   my $appclass = $args->{appclass} or die 'No appclass';
   my $worker   = $args->{worker  } or die 'No worker class';

   local_lib( $appclass );
   eval "require ${worker}";
   die $EVAL_ERROR if $EVAL_ERROR;
   return $worker->new( $args )->dispatch;
};

func 'distclean' => q{
   require File::Copy;

   my $appclass = shift or die 'No appclass';
   my $config   = config( $appclass );
   my $tempdir  = $config->{tempdir};

   die "Directory ${tempdir} cannot chdir: ${OS_ERROR}" unless chdir $tempdir;

   my @list = glob( '*.tar.gz' );

   for (@list) {
      unlink $_;
      s{ \.tar\.gz \z }{}mx;
      remove_tree( $_ ) if -e $_;
   }

   my $build = catdir( $config->{home}, '.cpanm' );

   die "Directory ${build} cannot chdir: ${OS_ERROR}" unless chdir $build;

   File::Copy::copy( 'build.log', 'last-build.log' ) if -e 'build.log';
   unlink 'build.log' if -e 'build.log';
   unlink 'latest-build' if -e 'latest-build';
   remove_tree( 'work' ) if -d 'work';
   return 'Installation cleaned';
};

func 'install_cpan_minus' => q{
   require Archive::Tar;

   my $appclass = shift or die 'No appclass';
   my $file     = shift or die 'No filename';
   my $config   = config ( $appclass );

   chdir $config->{tempdir};

   my $path = catfile( $config->{tempdir}, $file );

   die "File ${path} not found" unless -f $path;

   my $tar = Archive::Tar->new;

   $tar->read( $path );
   $tar->extract;
   $path =~ s{ \.tar\.gz \z }{}mx;

   die "Path ${path} not found" unless -e $path;

   my $cmd   = "${EXECUTABLE_NAME} ${path} App::cpanminus";
   my $cpanm = catfile( $config->{home}, 'perl5', 'bin', 'cpanm' );

   chdir $config->{home};
   qx( $cmd );
   die 'No cpanm' unless -x $cpanm;
   return 'Installed cpanm';
};

func 'install_distribution' => q{
   my $appclass = shift or die 'No appclass';
   my $file     = shift or die 'No filename';
   my $config   = config ( $appclass );

   chdir $config->{home};

   my $path  = $file !~ m{ \A [a-zA-Z0-9_]+ : }mx
             ? catfile( $config->{tempdir}, $file ) : $file;
   my $base  = catfile( $config->{home}, 'perl5' );
   my $cpanm = catfile( $base, 'bin', 'cpanm' );
   my $cmd   = "${cpanm} -l ${base} --notest ${path}"; qx( $cmd );
  (my $dist  = $file) =~ s{ \.tar\.gz \z }{}mx;

   return "Installed ${dist}";
};

func 'provision' => q{
   my $appclass = shift or die 'No appclass';
   my $worker   = shift;
   my $config   = config( $appclass );

   die 'No home' unless $config->{home} and -d $config->{home};
   mkpath( $config->{appldir}, { mode => 0750 } ) unless -d $config->{appldir};
   mkpath( $config->{logsdir}, { mode => 0750 } ) unless -d $config->{logsdir};
   mkpath( $config->{tempdir}, { mode => 0750 } ) unless -d $config->{tempdir};

   my $cfgfile  = $config->{cfgfile};

   unless (-f $cfgfile) {
      my $conf  = "{\n   \"name\" : \"worker\"\n}\n";
      die "Path ${cfgfile} cannot open - $!" unless open(my $fh, '>', $cfgfile);
      die "Path ${cfgfile} cannot write - $!" unless print $fh $conf;
      close $fh;
      die "Path ${cfgfile} cannot chmod - $!" unless chmod 0640, $cfgfile;
   }

   return unless $worker;

   local_lib( $appclass );
   eval "require ${worker}";

   return $EVAL_ERROR ? "${EVAL_ERROR}"
                      : sprintf 'version=%s', $worker->VERSION;
};

func 'remote_env' => q{
   my $appclass = shift or die 'No appclass';

   local_lib( $appclass );

   return join "\n", map { "${_}=".$ENV{ $_ } } keys %ENV;
};

func 'writefile' => q{
   my $appclass = shift or die 'No appclass';
   my $file     = shift or die 'No filename';
   my $path     = catfile( config( $appclass )->{tempdir}, $file );

   die "Path ${path} cannot open - ${OS_ERROR}" unless open(my $fh, '>', $path);
   die "Path ${path} cannot write - $OS_ERROR" unless print $fh $_[ 0 ];
   close $fh;
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

Peter Flanigan, C<< <pjfl@cpan.org> >>

=head1 License and Copyright

Copyright (c) 2024 Peter Flanigan. All rights reserved

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
