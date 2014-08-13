package App::MCP::Config;

use namespace::autoclean;

use Moo;
use App::MCP::Constants    qw( NUL TRUE );
use Class::Usul::Functions qw( fqdn );
use File::DataClass::Types qw( ArrayRef Directory File HashRef
                               NonEmptySimpleStr NonZeroPositiveInt
                               PositiveInt SimpleStr Str );
use Sys::Hostname          qw( hostname );

extends q(Class::Usul::Config::Programs);

has 'author'               => is => 'ro',   isa => NonEmptySimpleStr,
   default                 => 'Dave';

has 'clock_tick_interval'  => is => 'ro',   isa => NonZeroPositiveInt,
   default                 => 3;

has 'common_links'         => is => 'ro',   isa => ArrayRef,
   builder                 => sub { [ qw( css images js less ) ] };

has 'connect_params'       => is => 'ro',   isa => HashRef,
   default                 => sub { { quote_names => TRUE } };

has 'css'                  => is => 'ro',   isa => NonEmptySimpleStr,
   default                 => 'css/';

has 'database'             => is => 'ro',   isa => NonEmptySimpleStr,
   default                 => 'schedule';

has 'default_view'         => is => 'ro',   isa => SimpleStr, default => 'html';

has 'deflate_types'        => is => 'ro',   isa => ArrayRef[NonEmptySimpleStr],
   builder                 => sub {
      [ qw( text/css text/html text/javascript application/javascript ) ] };

has 'description'          => is => 'ro',   isa => SimpleStr, default => NUL;

has 'identity_file'        => is => 'lazy', isa => File,
   builder                 => sub { [ $_[ 0 ]->ssh_dir, 'id_rsa' ] },
   coerce                  => File->coercion;

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
   default                 => 'DAEMON';

has 'max_asset_size'       => is => 'ro',   isa => PositiveInt,
   default                 => 4_194_304;

has 'max_messages'         => is => 'ro',   isa => NonZeroPositiveInt,
   default                 => 3;

has 'max_web_session_time' => is => 'ro',  isa => PositiveInt, default => 3_600;

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

has 'nav_list'             => is => 'ro',   isa => ArrayRef,
   builder                 => sub {
      [ qw( job state_diagram help ) ] };

has 'port'                 => is => 'ro',   isa => NonZeroPositiveInt,
   default                 => 2012;

has 'preferences'          => is => 'ro',   isa => ArrayRef,
   builder                 => sub { [ qw( theme ) ] };

has 'request_class'        => is => 'ro',   isa => NonEmptySimpleStr,
   default                 => 'App::MCP::Request';

has 'secret'               => is => 'ro',   isa => NonEmptySimpleStr,
   default                 => hostname;

has 'schema_classes'       => is => 'ro',   isa => HashRef,
   builder                 => sub { {
      'mcp-model'          => 'App::MCP::Schema::Schedule', } };

has 'scrubber'             => is => 'ro',   isa => Str,
   default                 => '[^ +\,\-\./0-9@A-Z\\_a-z~]';

has 'server'               => is => 'ro',   isa => NonEmptySimpleStr,
   documentation           => 'Plack server class used for the event listener',
   default                 => 'Twiggy';

has 'serve_as_static'      => is => 'ro',   isa => NonEmptySimpleStr,
   default                 => 'css | favicon.ico | img | js | less';

has 'servers'              => is => 'ro',   isa => ArrayRef,
   builder                 => sub { [ fqdn ] };

has 'ssh_dir'              => is => 'lazy', isa => Directory,
   builder                 => sub { [ $_[ 0 ]->my_home, '.ssh' ] },
   coerce                  => Directory->coercion;

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
