package App::MCP::Config;

use utf8; # -*- coding: utf-8; -*-

use Class::Usul::Cmd::Constants qw( FALSE NUL TRUE );
use File::DataClass::Types      qw( ArrayRef Bool CodeRef Directory File HashRef
                                    LoadableClass NonEmptySimpleStr
                                    NonZeroPositiveInt Object Path PositiveInt
                                    SimpleStr Str Undef );
use Class::Usul::Cmd::Util      qw( decrypt );
use English                     qw( -no_match_vars );
use File::DataClass::IO         qw( io );
use Web::Components::Util       qw( fqdn );
use Moo;

with 'Web::Components::ConfigLoader';

my $except = [
   qw( BUILDARGS BUILD DOES connect_info has_config_file has_config_home
       has_local_config_file new SSL_VERIFY_NONE )
];

Class::Usul::Cmd::Constants->Dump_Except($except);

=pod

=encoding utf-8

=head1 Name

App::MCP::Config - Configuration class for the Master Control Program

=head1 Synopsis

   use App::MCP::Config;

=head1 Description

Configuration attribute defaults are overridden by loading a configuration
file. An optional local configuration file can also be read

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=item C<appclass>

The application class name. Required by component loader to find controllers,
models, and views

=cut

has 'appclass' => is => 'ro', isa => Str, required => TRUE;

=item C<appldir>

A synonym for 'home'

=cut

has 'appldir' => is => 'lazy', isa => Directory, default => sub { shift->home };

=item C<authentication>

Configuration parameters for the plugin authentication system

=cut

has 'authentication' =>
   is      => 'ro',
   isa     => HashRef,
   default => sub { { default_realm => 'DBIC' } };

=item C<bin>

A directory object which locates the applications executable files

=cut

has 'bin' =>
   is      => 'lazy',
   isa     => Directory,
   default => sub { shift->pathname->parent };

=item C<bug_attachments>

A hash reference of parameters used to configure the bug attachment uploads

=cut

has 'bug_attachments' =>
   is      => 'lazy',
   isa     => HashRef,
   default => sub {
      my $self = shift;

      return {
         directory  => $self->vardir->catdir('bugs'),
         extensions => 'csv|doc|png|txt',
         sharedir   => $self->rootdir->catdir('bugs')
      };
   };

=item C<clock_tick_interval>

A non zero positive integer that defaults to B<3>.

=cut

has 'clock_tick_interval' =>
   is      => 'ro',
   isa     => NonZeroPositiveInt,
   default => 3;

=item C<component_loader>

Configuration parameters used by the component loader

=cut

has 'component_loader' =>
   is      => 'ro',
   isa     => HashRef,
   default => sub {
      return { should_log_errors => FALSE, should_log_messages => TRUE };
   };

=item C<connect_info>

Used to connect to the database, the 'dsn', 'db_username', and 'db_password'
attributes are returned in an array reference. The password will be decoded
and decrypted

=cut

has 'connect_info' =>
   is      => 'lazy',
   isa     => ArrayRef,
   default => sub {
      my $self     = shift;
      my $password = decrypt NUL, $self->db_password;

      return [$self->dsn, $self->db_username, $password, $self->db_extra];
   };

=item C<cron_log_interval>

A positive integer that defaults to B<0>.

=cut

has 'cron_log_interval' => is => 'ro', isa => PositiveInt, default => 0;

=item C<db_extra>

Additional attributes passed to the database connection method

=cut

has 'db_extra' =>
   is      => 'ro',
   isa     => HashRef,
   default => sub { { AutoCommit => TRUE } };

=item C<db_password>

Password used to connect to the database. This has no default. It should be
set using the command C<bin/mcp-schema --store-password> before the application
is started

=cut

has 'db_password' => is => 'ro', isa => Str;

=item C<db_username>

The username used to connect to the database

=cut

has 'db_username' => is => 'ro', isa => Str, default => 'mcp';

=item C<deployment>

Defaults to C<development>. Should be overridden in the local configuration
file. Used to modify the server output depending on deployment environment.
For example, any value not C<development> will prevent the rendering of an
exception to the end user

=cut

has 'deployment' => is => 'ro', isa => Str, default => 'development';

=item C<default_route>

The applications default route used as a target for redirects when the
request does get as far as the mount point

=cut

has 'default_route' => is => 'ro', isa => Str, default => '/mcp/login';

=item C<default_view>

A simple string which defaults to B<html>.

=cut

has 'default_view' => is => 'ro', isa => SimpleStr, default => 'html';

=item C<deflate_types>

List of mime types that the middleware will compress on the fly if the
request allows for it

=cut

has 'deflate_types' =>
   is      => 'ro',
   isa     => ArrayRef[Str],
   default => sub {
      return [
         qw( application/javascript image/svg+xml text/css text/html
         text/javascript )
      ];
   };

=item C<documentation>

A hash reference of parameters used to configure the documentation viewer

=cut

has 'documentation' =>
   is      => 'lazy',
   isa     => HashRef,
   default => sub {
      my $self = shift;

      return {
         directory  => $self->bin->parent->catdir('lib'),
         extensions => 'pm',
         sharedir   => $self->rootdir->catdir('file')
      };
   };

=item C<dsn>

String used to select a database type and specific database by name

=cut

has 'dsn' => is => 'ro', isa => Str, default => 'dbi:Pg:dbname=schedule';

=item C<encoding>

The output encoding used by the application

=cut

has 'encoding' => is => 'ro', isa => Str, default => 'utf-8';

=item C<icons>

A partial string path from the document root to the file containing SVG
symbols used when generating HTML

=cut

has 'icons' => is => 'ro', isa => Str, default => 'img/icons.svg';

=item C<identity_file>

A file object reference that defaults to the F<id_rsa> file in the L</ssh_dir>
directory

=cut

has 'identity_file' =>
   is      => 'lazy',
   isa     => File|Path,
   coerce  => TRUE,
   default => sub { shift->ssh_dir->catfile('id_rsa') };

=item C<library_class>

A non empty simple string which defaults to B<App::MCP::SSHLibrary>.

=cut

has 'library_class' =>
   is      => 'ro',
   isa     => NonEmptySimpleStr,
   default => 'App::MCP::SSHLibrary';

=item C<local_tz>

The applications local time zone

=cut

has 'local_tz' => is => 'ro', isa => Str, default => 'Europe/London';

=item C<logdir>

Directory containing logfiles

=cut

has 'logdir' =>
   is      => 'lazy',
   isa     => Directory,
   default => sub { shift->vardir->catdir('log') };

=item C<logfile>

Set in the configuration file, the name of the logfile used by the logging
class

=cut

has 'logfile' =>
   is       => 'lazy',
   isa      => File|Path|Undef,
   init_arg => undef,
   default  => sub {
      my $self = shift;

      return $self->logdir->catfile($self->_logfile);
   };

has '_logfile' =>
   is       => 'ro',
   isa      => Str,
   default  => 'app-mcp.log',
   init_arg => 'logfile';

=item C<max_asset_size>

A positive integer that defaults to B<4_194_304>.

=cut

has 'max_asset_size' =>
   is      => 'ro',
   isa     => PositiveInt,
   default => 4_194_304;

=item C<max_messages>

A non zero positive integer that defaults to B<3>.

=cut

has 'max_messages' => is => 'ro', isa => NonZeroPositiveInt, default => 3;

=item C<max_web_session_time>

A positive integer that defaults to B<3_600>.

=cut

has 'max_web_session_time' => is => 'ro', isa => PositiveInt, default => 3_600;

=item C<max_api_session_time>

A positive integer that defaults to B<300>.

=cut

has 'max_api_session_time' => is => 'ro', isa => PositiveInt, default => 300;

=item C<max_ssh_worker_calls>

A positive integer that defaults to B<0>.

=cut

has 'max_ssh_worker_calls' => is => 'ro', isa => PositiveInt, default => 0;

=item C<max_ssh_workers>

A non zero positive integer that defaults to B<3>. The maximum number of SSH
worker processes

=cut

has 'max_ssh_workers' =>
   is            => 'ro',
   isa           => NonZeroPositiveInt,
   documentation => 'Maximum number of SSH worker processes',
   default       => 3;

=item C<mount_point>

A non empty simple string which defaults to B</>.

=cut

has 'mount_point' => is => 'ro', isa => NonEmptySimpleStr, default => '/mcp';

=item C<name>

The display name for the applicaton

=cut

has 'name' => is => 'ro', isa => Str, default => 'Master Control Program';

=item C<navigation>

Hash reference of configuration attributes applied the
L<Web::Components::Navigation> object

=cut

has 'navigation' =>
   is       => 'lazy',
   isa      => HashRef,
   init_arg => undef,
   default  => sub {
      my $self = shift;

      return {
         messages => { 'buffer-limit' => $self->max_messages },
         title => $self->name . ' v' . App::MCP->VERSION,
         title_abbrev => 'MCP',
         %{$self->_navigation},
         global => [
            qw( admin/menu job/list state/view )
         ],
      };
   };

has '_navigation' =>
   is       => 'ro',
   isa      => HashRef,
   init_arg => 'navigation',
   default  => sub { {} };

=item C<pathname>

File object for absolute pathname to the running program

=cut

has 'pathname' => is => 'ro', isa => File, default => sub {
   my $name = $PROGRAM_NAME;

   $name = '-' eq substr($name, 0, 1) ? $EXECUTABLE_NAME : $name;

   return io((split m{ [ ][\-][ ] }mx, $name)[0])->absolute;
};

=item C<port>

A non zero positive integer that defaults to B<2012>.

=cut

has 'port' => is => 'ro', isa => NonZeroPositiveInt, default => 2012;

=item C<prefix>

Used as a prefix when creating identifiers

=cut

has 'prefix' => is => 'ro', isa => Str, default => 'mcp';

=item C<redirect>

The default action path to redirect to after logging in, changing password etc.

=cut

has 'redirect' => is => 'ro', isa => SimpleStr, default => 'job/list';

=item C<redis>

Configuration hash reference used to configure the connection to the Redis
cache

=cut

has 'redis' => is => 'ro', isa => HashRef, default => sub { {} };

=item registration

Boolean which defaults false. If true user registration is allowed otherwise
it is unavailable

=cut

has 'registration' => is => 'ro', isa => Bool, coerce => TRUE, default => FALSE;

=item C<request>

Hash reference passed to the request object factory constructor by the
component loader. Includes;

=over 3

=item max_messages

The maximum number of response to post messages to buffer both in the session
object where they are stored and the JS object where they are displayed

=item prefix

See 'prefix'

=item request_roles

List of roles to be applied to the request class base

=item serialise_session_attr

List of session attributes that are included for serialisation to the CSRF
token

=item session_attr

A list of names, types, and default values. These are composed into the
session object

=back

=cut

has 'request' => is => 'lazy', isa => HashRef, default => sub {
   my $self = shift;

   return {
      max_messages  => $self->max_messages,
      max_sess_time => $self->max_web_session_time,
      prefix        => $self->prefix,
      request_roles => [
         qw( L10N Session JSON Cookie Headers Compat Authen::HTTP)
      ],
      serialise_session_attr => [ qw( id ) ],
      session_attr => {
         email         => [ Str, NUL ],
         enable_2fa    => [ Bool, FALSE ],
         id            => [ PositiveInt, 0 ],
         link_display  => [ Str, 'both' ],
         menu_location => [ Str, 'header' ],
         realm         => [ Str, NUL ],
         role          => [ Str, NUL ],
         skin          => [ Str, $self->skin ],
         theme         => [ Str, 'light' ],
         timezone      => [ Str, $self->local_tz ],
         wanted        => [ Str, NUL ],
      },
   };
};

=item C<rootdir>

Directory which is the document root for assets being served by the application

=cut

has 'rootdir' =>
   is      => 'lazy',
   isa     => Directory,
   default => sub { shift->vardir->catdir('root') };

=item C<rundir>

Used to store runtime files

=cut

has 'rundir' =>
   is      => 'lazy',
   isa     => Directory,
   default => sub { shift->tempdir };

=item C<schema_class>

The name of the lazily loaded database schema class

=cut

has 'schema_class' =>
   is      => 'lazy',
   isa     => LoadableClass,
   coerce  => TRUE,
   default => 'App::MCP::Schema::Schedule';

=item C<script>

Name of the program being executed. Appears on the manual page output

=cut

has 'script' =>
   is      => 'lazy',
   isa     => Str,
   default => sub { shift->pathname->basename };

=item C<scrubber>

A string which defaults to B<[^ +\,\-\./0-9@A-Z\\_a-z]>.

=cut

has 'scrubber' =>
   is      => 'ro',
   isa     => Str,
   default => '[^ +\,\-\./0-9@A-Z\\_a-z~]';

=item C<server>

A non empty simple string which defaults to B<Twiggy>. The Plack server class
used for the event listener

=cut

has 'server' =>
   is            => 'ro',
   isa           => NonEmptySimpleStr,
   documentation => 'Plack server class used for the event listener',
   default       => 'Twiggy';

=item C<servers>

An array reference of non empty simple strings that defaults to
B<[ fully_qualified_domain_name_of_this_host ]>

=cut

has 'servers' =>
   is      => 'ro',
   isa     => ArrayRef[NonEmptySimpleStr],
   default => sub { [ fqdn ] };

=item C<skin>

A non empty simple string which defaults to B<default>. The name of the default
CSS skin

=cut

has 'skin' => is => 'ro', isa => NonEmptySimpleStr, default => 'default';

=item C<sqldir>

Directory object which contains the SQL DDL files used to create, populate
and upgrade the database

=cut

has 'sqldir' => is => 'lazy', isa => Directory,
   default => sub { shift->vardir->catdir('sql') };

=item C<ssh_dir>

A directory object reference that defaults to the F<.ssh> directory in the
users home

=cut

has 'ssh_dir' =>
   is      => 'lazy',
   isa     => Directory,
   coerce  => TRUE,
   default => sub { shift->home->catdir('.ssh') };

=item C<static>

A non empty simple string which defaults to B<css | file | font | img | js>.

=cut

has 'static' =>
   is      => 'ro',
   isa     => NonEmptySimpleStr,
   default => 'css | file | font | img | js';

=item C<stop_signals>

A non empty simple string which defaults to B<TERM,10,KILL,1>.

=cut

has 'stop_signals' =>
   is      => 'ro',
   isa     => NonEmptySimpleStr,
   default => 'TERM,10,KILL,1';

=item C<tempdir>

The temporary directory used by the application

=cut

has 'tempdir' =>
   is      => 'lazy',
   isa     => Directory,
   default => sub { shift->vardir->catdir('tmp') };

=item C<template_wrappers>

Defines the names of the C<site/html> and C<site/wrapper> templates used to
produce all the pages

=cut

has 'template_wrappers' =>
   is      => 'ro',
   isa     => HashRef,
   default => sub { { html => 'base', wrapper => 'standard' } };

=item C<token_lifetime>

Time in seconds the CSRF token has to live before it is declared invalid

=cut

has 'token_lifetime' => is => 'ro', isa => PositiveInt, default => 3_600;

=item C<user>

Configuration options for the C<User> result class. Includes C<load_factor>
used in the encrypting of passwords, C<default_password> used when creating new
users, C<min_name_len> minimum user name length, and C<min_password_len>
minumum password length

=cut

has 'user' =>
   is      => 'ro',
   isa     => HashRef,
   default => sub {
      return {
         default_password => 'welcome',
         load_factor      => 14,
         min_name_len     => 3,
         min_password_len => 3,
      };
   };

=item C<vardir>

Directory where all non program files and directories are expected to be found

=cut

has 'vardir' =>
   is      => 'ro',
   isa     => Directory,
   coerce  => TRUE,
   default => sub { io['var'] };

=item C<wcom_resources>

Names of the JS management objects

=cut

has 'wcom_resources' =>
   is      => 'ro',
   isa     => HashRef[Str],
   default => sub {
      return {
         data_structure => 'WCom.Form.DataStructure',
         downloadable   => 'WCom.Table.Role.Downloadable',
         form_util      => 'WCom.Form.Util',
         modal          => 'WCom.Modal',
         navigation     => 'WCom.Navigation.manager',
         table_renderer => 'WCom.Table.Renderer.manager',
         toggle         => 'WCom.Form.Toggle'
      };
   };

=item web_components

Configuration hash reference for L<Web::Components> loaded from the
F<Contoller>, F<Model>, and F<View> subdirectories of the application
namespace

=cut

has 'web_components' =>
   is      => 'lazy',
   isa     => HashRef,
   default => sub {
      return {
         'Model::State' => { max_jobs => 10_000 }
      };
   };

use namespace::autoclean;

1;

__END__

=back

=head1 Subroutines/Methods

Defines no subroutines or methods

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Moo>

=item L<File::DataClass>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module.  Please report problems to the address
below.  Patches are welcome

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
