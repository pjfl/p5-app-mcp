# Name

App::MCP - Master Control Program - Dependency and time based job scheduler

# Version

Describes version v0.6.$Rev: 20 $ of [App::MCP](https://metacpan.org/pod/App%3A%3AMCP)

# Synopsis

    use MCP;

# Description

Dependency and time based job scheduler

# Installation

The **App-MCP** repository contains meta data that lists the CPAN modules
used by the application. Modern Perl CPAN distribution installers (like
[App::cpanminus](https://metacpan.org/pod/App%3A%3Acpanminus)) use this information to install the required dependencies
when this application is installed.

**Requirements:**

- Perl 5.12.0 or above
- Git - to install **App::MCP** from Github

To find out if Perl is installed and which version; at a shell prompt type:

    perl -v

To find out if Git is installed, type:

    git --version

If you don't already have it, bootstrap [App::cpanminus](https://metacpan.org/pod/App%3A%3Acpanminus) with:

    curl -L http://cpanmin.us | perl - --sudo App::cpanminus

What follows are the instructions for a production deployment. If you are
installing for development purposes skip ahead to ["Development Installs"](#development-installs)

If this is a production deployment create a user, `mcp`, and then
login as (`su` to) the `mcp` user before carrying out the next step.

If you `su` to the `mcp` user unset any Perl environment variables first.

Next install [local::lib](https://metacpan.org/pod/local%3A%3Alib) with:

    cpanm --notest --local-lib=~/local local::lib && \
       eval $(perl -I ~/local/lib/perl5/ -Mlocal::lib=~/local)

The second statement sets environment variables to include the local
Perl library. You can append the output of the `perl` command to your
shell startup if you want to make it permanent. Without the correct
environment settings Perl will not be able to find the installed
dependencies and the following will fail, badly.

Upgrade the installed version of [Module::Build](https://metacpan.org/pod/Module%3A%3ABuild) with:

    cpanm --notest Module::Build

Install **App-MCP** with:

    cpanm --notest git://github.com/pjfl/p5-app-mcp.git

Watch out for broken Github download URIs, the one above is the
correct format

Although this is a _simple_ application it is composed of many CPAN
distributions and, depending on how many of them are already available,
installation may take a while to complete. The flip side is that there are no
external dependencies like Node.js or Grunt to install. At the risk of
installing broken modules (they are only going into a local library) tests are
skipped by running `cpanm` with the `--notest` option. This has the advantage
that installs take less time but the disadvantage that you will not notice a
broken module until the application fails.

If that fails run it again with the `--force` option:

    cpanm --force git:...

## Development Installs

Assuming you have the Perl environment setup correctly, clone
**App-MCP** from the repository with:

    git clone https://github.com/pjfl/p5-app-mcp.git mcp
    cd mcp
    cpanm --notest --installdeps .

To install the development toolchain execute:

    cpanm Dist::Zilla
    dzil authordeps | cpanm --notest

## Post Installation

Once installation is complete run the post install:

    bin/mcp-cli install

This will allow you to edit the credentials that the application will
use to connect to the database, it then creates that user and the
database schema. Next it populates the database with initial data
including creating an administration user. You will need the database
administration password to complete this step

By default the development server will run at http://localhost:5000 and can be
started in the foreground with:

    plackup bin/mcp-server

Users must authenticate against the `User` table in the database.  The default
user is `mcp` password `mcp`. You should change that via the change password
page, the link for which is on the user settings menu

## Service Startup

To start the production server in the background listening on a Unix socket:

    bin/mcp-daemon start

The `mcp-daemon` program provides normal SysV init script
semantics. Additionally the daemon program will write an `init` script to
standard output in response to the command:

    bin/mcp-daemon get_init_file

As the root user you should redirect this to `/etc/init.d/mcp`, then
restart the MCP service with:

    service mcp restart

# Configuration and Environment

The prefered production deployment method uses the `FCGI` engine over
a socket to `nginx`. There is an example
\[configuration recipe\](https://www.roxsoft.co.uk/doh/static/en/posts/Blog/Debian-Nginx-Letsencrypt.sh-Configuration-Recipe.html)
for this method of deployment

# Subroutines/Methods

Defines the following class methods;

- `env_var`

        $value = App::MCP->env_var('name', 'new_value');

    Looks up the environment variable and returns it's value. Also acts as a
    mutator if provided with an optional new value. Uppercases and prefixes
    the environment variable key

- `schema_version`

        $version = App::MCP->schema_version;

    Returns the version number of the current schema

# Diagnostics

Running one of the command line programs like `bin/mcp-cli` calling
the `dump-config` method will output a list of configuration options,
their defining class, documentation, and current value

Help for command line options can be found be running:

    bin/mcp-cli list-methods
    bin/mcp-cli help <method>

The `list-methods` command is available to all of the application programs
(except `mcp-server`)

# Dependencies

- [Class::Usul::Cmd](https://metacpan.org/pod/Class%3A%3AUsul%3A%3ACmd)

# Incompatibilities

There are no known incompatibilities in this module

# Bugs and Limitations

There are no known bugs in this module.
Please report problems to the address below.
Patches are welcome

# Acknowledgements

Larry Wall - For the Perl programming language

# Author

Peter Flanigan, `<pjfl@cpan.org>`

# License and Copyright

Copyright (c) 2025 Peter Flanigan. All rights reserved

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See [perlartistic](https://metacpan.org/pod/perlartistic)

This program is distributed in the hope that it will be useful,
but WITHOUT WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE
