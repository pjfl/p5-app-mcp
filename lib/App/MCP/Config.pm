package App::MCP::Config;

use namespace::autoclean;

use App::MCP::Constants    qw( NUL TRUE );
use Class::Usul::Functions qw( fqdn );
use File::DataClass::Types qw( ArrayRef Directory File HashRef
                               NonEmptySimpleStr NonZeroPositiveInt
                               PositiveInt SimpleStr Str );
use Sys::Hostname          qw( hostname );
use Moo;

extends q(Class::Usul::Config::Programs);

has 'author'               => is => 'ro',   isa => NonEmptySimpleStr,
   default                 => 'Dave';

has 'clock_tick_interval'  => is => 'ro',   isa => NonZeroPositiveInt,
   default                 => 3;

has 'common_links'         => is => 'ro',   isa => ArrayRef[NonEmptySimpleStr],
   builder                 => sub { [ qw( css images js less ) ] };

has 'connect_params'       => is => 'ro',   isa => HashRef,
   builder                 => sub { { quote_names => TRUE } };

has 'cron_log_interval'    => is => 'ro',   isa => PositiveInt,
   default                 => 0;

has 'css'                  => is => 'ro',   isa => NonEmptySimpleStr,
   default                 => 'css/';

has 'database'             => is => 'ro',   isa => NonEmptySimpleStr,
   default                 => 'schedule';

has 'default_view'         => is => 'ro',   isa => SimpleStr, default => 'html';

has 'deflate_types'        => is => 'ro',   isa => ArrayRef[NonEmptySimpleStr],
   builder                 => sub {
      [ qw( text/css text/html text/javascript application/javascript ) ] };

has 'description'          => is => 'ro',   isa => SimpleStr, default => NUL;

has 'identity_file'        => is => 'lazy', isa => File, coerce => TRUE,
   builder                 => sub { $_[ 0 ]->ssh_dir->catfile( 'id_rsa' ) };

has 'images'               => is => 'ro',   isa => NonEmptySimpleStr,
   default                 => 'img/';

has 'js'                   => is => 'ro',   isa => NonEmptySimpleStr,
   default                 => 'js/';

has 'keywords'             => is => 'ro',   isa => SimpleStr, default => NUL;

has 'less'                 => is => 'ro',   isa => NonEmptySimpleStr,
   default                 => 'less/';

has 'library_class'        => is => 'ro',   isa => NonEmptySimpleStr,
   default                 => 'App::MCP::SSHLibrary';

has 'load_factor'          => is => 'ro',   isa => NonZeroPositiveInt,
   default                 => 14;

has 'log_key'              => is => 'ro',   isa => NonEmptySimpleStr,
   default                 => 'daemon';

has 'max_asset_size'       => is => 'ro',   isa => PositiveInt,
   default                 => 4_194_304;

has 'max_messages'         => is => 'ro',   isa => NonZeroPositiveInt,
   default                 => 3;

has 'max_web_session_time' => is => 'ro',   isa => PositiveInt,
   default                 => 3_600;

has 'max_api_session_time' => is => 'ro',   isa => PositiveInt,
   default                 => 300;

has 'max_ssh_worker_calls' => is => 'ro',   isa => PositiveInt,
   default                 => 0;

has 'max_ssh_workers'      => is => 'ro',   isa => NonZeroPositiveInt,
   documentation           => 'Maximum number of SSH worker processes',
   default                 => 3;

has 'monikers'             => is => 'ro',   isa => HashRef[NonEmptySimpleStr],
   builder                 => sub { {} };

has 'mount_point'          => is => 'ro',   isa => NonEmptySimpleStr,
   default                 => '/';

has 'nav_list'             => is => 'ro',   isa => ArrayRef[NonEmptySimpleStr],
   builder                 => sub { [ qw( config job state_diagram help ) ] };

has 'port'                 => is => 'ro',   isa => NonZeroPositiveInt,
   default                 => 2012;

has 'preferences'          => is => 'ro',   isa => ArrayRef[NonEmptySimpleStr],
   builder                 => sub { [ qw( theme ) ] };

has 'request_class'        => is => 'ro',   isa => NonEmptySimpleStr,
   default                 => 'App::MCP::Request';

has 'secret'               => is => 'ro',   isa => NonEmptySimpleStr,
   default                 => hostname;

has 'schema_classes'       => is => 'ro',   isa => HashRef[NonEmptySimpleStr],
   builder                 => sub { {
      'mcp-model'          => 'App::MCP::Schema::Schedule', } };

has 'scrubber'             => is => 'ro',   isa => Str,
   default                 => '[^ +\,\-\./0-9@A-Z\\_a-z~]';

has 'server'               => is => 'ro',   isa => NonEmptySimpleStr,
   documentation           => 'Plack server class used for the event listener',
   default                 => 'Twiggy';

has 'serve_as_static'      => is => 'ro',   isa => NonEmptySimpleStr,
   default                 => 'css | favicon.ico | img | js | less';

has 'servers'              => is => 'ro',   isa => ArrayRef[NonEmptySimpleStr],
   builder                 => sub { [ fqdn ] };

has 'ssh_dir'              => is => 'lazy', isa => Directory, coerce => TRUE,
   builder                 => sub { $_[ 0 ]->my_home->catdir( '.ssh' ) };

has 'stop_signals'         => is => 'ro',   isa => NonEmptySimpleStr,
   default                 => 'TERM,10,KILL,1';

has 'template'             => is => 'ro',   isa => NonEmptySimpleStr,
   default                 => 'form';

has 'title'                => is => 'ro',   isa => NonEmptySimpleStr,
   default                 => 'MCP';

has 'theme'                => is => 'ro',   isa => NonEmptySimpleStr,
   default                 => 'green';

1;

__END__

=pod

=encoding utf8

=head1 Name

App::MCP::Config - One-line description of the modules purpose

=head1 Synopsis

   use App::MCP::Config;
   # Brief but working code examples

=head1 Description

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=item C<author>

A non empty simple string which defaults to B<Dave>.

=item C<clock_tick_interval>

A non zero positive integer that defaults to B<3>.

=item C<common_links>

An array reference of non empty simple strings that defaults to
B<[ css images js less ]>

=item C<connect_params>

A hash reference which defaults to B<< { quote_names => TRUE } >>

=item C<cron_log_interval>

A positive integer that defaults to B<0>.

=item C<css>

A non empty simple string which defaults to B<css/>.

=item C<database>

A non empty simple string which defaults to B<schedule>.

=item C<default_view>

A simple string which defaults to B<html>.

=item C<deflate_types>


An array reference of non empty simple strings that defaults to
B<[ text/css text/html text/javascript application/javascript ]>

=item C<description>

A simple string which defaults to B<NUL>.

=item C<identity_file>

A file object reference that defaults to the F<id_rsa> file in the L</ssh_dir>
directory

=item C<images>

A non empty simple string which defaults to B<img/>.

=item C<js>

A non empty simple string which defaults to B<js/>.

=item C<keywords>

A simple string which defaults to B<NUL>.

=item C<less>

A non empty simple string which defaults to B<less/>.

=item C<library_class>

A non empty simple string which defaults to B<App::MCP::SSHLibrary>.

=item C<load_factor>

A non zero positive integer that defaults to B<14>.

=item C<log_key>

A non empty simple string which defaults to B<DAEMON>.

=item C<max_asset_size>

A positive integer that defaults to B<4_194_304>.

=item C<max_messages>

A non zero positive integer that defaults to B<3>.

=item C<max_web_session_time>

A positive integer that defaults to B<3_600>.

=item C<max_api_session_time>

A positive integer that defaults to B<300>.

=item C<max_ssh_worker_calls>

A positive integer that defaults to B<0>.

=item C<max_ssh_workers>

A non zero positive integer that defaults to B<3>. The maximum number of SSH
worker processes

=item C<monikers>

A hash reference of non empty simple strings which defaults to B<{}>

=item C<mount_point>

A non empty simple string which defaults to B</>.

=item C<nav_list>

An array reference of non empty simple strings that defaults to
B<[ config job state_diagram help ]>

=item C<port>

A non zero positive integer that defaults to B<2012>.

=item C<preferences>

An array reference of non empty simple strings that defaults to
B<[ theme ]>

=item C<request_class>

A non empty simple string which defaults to B<App::MCP::Request>.

=item C<secret>

A non empty simple string which defaults to B<hostname>.

=item C<schema_classes>

A hash reference of non empty simple strings which defaults to
B<< { 'mcp-model' => 'App::MCP::Schema::Schedule' } >>

=item C<scrubber>

A string which defaults to B<[^ +\,\-\./0-9@A-Z\\_a-z]>.

=item C<server>

A non empty simple string which defaults to B<Twiggy>. The Plack server class
used for the event listener

=item C<serve_as_static>

A non empty simple string which defaults to
B<css | favicon.ico | img | js | less>.

=item C<servers>

An array reference of non empty simple strings that defaults to
B<[ fqdn ]>

=item C<ssh_dir>

A directory object reference that defaults to the F<.ssh> directory in the
users home

=item C<stop_signals>

A non empty simple string which defaults to B<TERM,10,KILL,1>.

=item C<template>

A non empty simple string which defaults to B<form>.

=item C<title>

A non empty simple string which defaults to B<MCP>.

=item C<theme>

A non empty simple string which defaults to B<green>.

=back

=head1 Subroutines/Methods

=head1 Diagnostics

=head1 Dependencies

=over 3

=item L<Class::Usul>

=item L<File::DataClass>

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
