package App::MCP;

use 5.010001;
use strictures;
use version; our $VERSION = qv( sprintf '0.5.%d', q$Rev: 43 $ =~ /\d+/gmx );

use Class::Usul::Cmd::Util qw( ns_environment );

sub env_var {
   my ($class, $k, $v) = @_;

   return ns_environment(__PACKAGE__, $k, $v);
}

sub schema_version {
   return '0.5.41';
}

1;

# =for html <p><center><img src="http://cpan.org/authors/id/P/PJ/PJFL/images/one_thousand_words.png" width="882" height="462" /></center></p>

__END__

=pod

=encoding utf-8

=head1 Name

App::MCP - Master Control Program - Dependency and time based job scheduler

=head1 Version

Describes version v0.5.$Rev: 43 $ of L<App::MCP>

=head1 Synopsis

=head1 Description

=head1 Configuration and Environment

=head1 Subroutines/Methods

Defines the following methods;

=over 3

=item C<env_var>

   $value = App::MCP->env_var( 'name', 'new_value' );

Looks up the environment variable and returns it's value. Also acts as a
mutator if provided with an optional new value. Uppercases and prefixes
the environment variable key

=back

=head1 Installation

The B<App-MCP> repository contains meta data that lists the CPAN modules
used by the application. Modern Perl CPAN distribution installers (like
L<App::cpanminus>) use this information to install the required dependencies
when this application is installed.

B<Requirements:>

=over 3

=item Perl 5.12.0 or above

=item Git - to install B<App::MCP> from Github

=back

To find out if Perl is installed and which version; at a shell prompt type:

   perl -v

To find out if Git is installed, type:

   git --version

If you don't already have it, bootstrap L<App::cpanminus> with:

   curl -L http://cpanmin.us | perl - --sudo App::cpanminus

What follows are the instructions for a production deployment. If you are
installing for development purposes skip ahead to L</Development Installs>

If this is a production deployment create a user, C<mcp>, and then
login as (C<su> to) the C<mcp> user before carrying out the next step.

If you C<su> to the C<mcp> user unset any Perl environment variables first.

Next install L<local::lib> with:

   cpanm --notest --local-lib=~/local local::lib && \
      eval $(perl -I ~/local/lib/perl5/ -Mlocal::lib=~/local)

The second statement sets environment variables to include the local
Perl library. You can append the output of the C<perl> command to your
shell startup if you want to make it permanent. Without the correct
environment settings Perl will not be able to find the installed
dependencies and the following will fail, badly.

Upgrade the installed version of L<Module::Build> with:

   cpanm --notest Module::Build

Install B<App-MCP> with:

   cpanm --notest git://github.com/pjfl/p5-app-mcp.git

Watch out for broken Github download URIs, the one above is the
correct format

Although this is a I<simple> application it is composed of many CPAN
distributions and, depending on how many of them are already available,
installation may take a while to complete. The flip side is that there are no
external dependencies like Node.js or Grunt to install. At the risk of
installing broken modules (they are only going into a local library) tests are
skipped by running C<cpanm> with the C<--notest> option. This has the advantage
that installs take less time but the disadvantage that you will not notice a
broken module until the application fails.

If that fails run it again with the C<--force> option:

   cpanm --force git:...

=head2 Development Installs

Assuming you have the Perl environment setup correctly, clone
B<App-MCP> from the repository with:

   git clone https://github.com/pjfl/p5-app-mcp.git mcp
   cd mcp
   cpanm --notest --installdeps .

To install the development toolchain execute:

   cpanm Dist::Zilla
   dzil authordeps | cpanm --notest

=head2 Post Installation

Once installation is complete run the post install:

   bin/mcp-cli install

This will allow you to edit the credentials that the application will
use to connect to the database, it then creates that user and the
database schema. Next it populates the database with initial data
including creating an administration user. You will need the database
administration password to complete this step

By default the development server will run at http://localhost:5000 and can be
started in the foreground with:

   plackup bin/mcp-listener

Users must authenticate against the C<User> table in the database.  The default
user is C<mcp> password C<mcp>. You should change that via the change password
page, the link for which is on the user settings menu. To start the
production server in the background listening on a Unix socket:

   bin/mcp-daemon start

The C<mcp-daemon> program provides normal SysV init script
semantics. Additionally the daemon program will write an C<init> script to
standard output in response to the command:

   bin/mcp-daemon get_init_file

As the root user you should redirect this to F</etc/init.d/mcp>, then
restart the MCP service with:

   service mcp restart

=head1 Configuration and Environment

The prefered production deployment method uses the C<FCGI> engine over
a socket to C<nginx>. There is an example
[configuration recipe](https://www.roxsoft.co.uk/doh/static/en/posts/Blog/Debian-Nginx-Letsencrypt.sh-Configuration-Recipe.html)
for this method of deployment

=head1 Diagnostics

Running one of the command line programs like F<bin/mcp-cli> calling
the C<dump-config> method will output a list of configuration options,
their defining class, documentation, and current value

Help for command line options can be found be running:

   bin/mcp-cli list-methods
   bin/mcp-cli help <method>

The C<list-methods> command is available to all of the application programs
(except C<mcp-listener>)

=head1 Dependencies

=over 3

=item L<Class::Usul::Cmd>

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
