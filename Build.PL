# @(#)$Id$

use strict;
use warnings;
use inc::Bob; # Module::Build subclass
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

Bob->new( {
   module     => q(App::MCP),
   home_page  => q(http://www.roxsoft.co.uk),
   requires   => {
      'perl'                            => 5.010,
      'version'                         => 0.77,
      'Class::C3::Componentised'        => 1.001000,
      'Class::Usul'                     => q(0.9.0),
      'Daemon::Control'                 => 0.000009,
      'DBIx::Class'                     => 0.08126,
      'DBIx::Class::Helpers'            => 2.016001,
      'DBIx::Class::TimeStamp'          => 0.14,
      'File::DataClass'                 => q(0.12.0),
   },
   recommends            => {
      'App::cpanminus'   => 1.4004 },
   configure_requires    => {
      'version'          => 0.77,
      'Module::Build'    => 0.38, },
   build_requires        => {
      'Exception::Class' => 1.23,
      'Test::More'       => 0.74, },
} )->create_build_script; # Goal!

# Local Variables:
# eval: (load-project-state "app-mcp")
# mode: perl
# tab-title: MCP
# tab-width: 3
# End:
