# @(#)$Ident: Build.PL 2013-08-07 00:43 pjf ;

use strict;
use warnings;
use inc::Bob; # Module::Build subclass
use version; our $VERSION = qv( sprintf '0.2.%d', q$Rev: 22 $ =~ /\d+/gmx );

Bob->new( {
   module    => 'App::MCP',
   home_page => 'http://www.roxsoft.co.uk',
   requires  => {
      'perl'                       => 5.010001,
      'local::lib'                 => 1.008004,
      'namespace::sweep'           => 0.006,
      'parent'                     => 0.224,
      'Algorithm::Cron'            => 0.04,
      'AnyEvent'                   => 7.01,
      'Async::Interrupt'           => 1.1,
      'CatalystX::Usul'            => q(0.8.0),
      'Class::C3::Componentised'   => 1.001000,
      'Class::Workflow'            => 0.11,
      'Class::Usul'                => q(0.21.0),
      'Daemon::Control'            => q(0.000009),
      'Data::Validation'           => q(0.11.0),
      'DateTime'                   => 0.66,
      'DBIx::Class'                => 0.08204,
      'DBIx::Class::Helpers'       => 2.016001,
      'DBIx::Class::InflateColumn::Object::Enum' => 0.04,
      'DBIx::Class::TimeStamp'     => 0.14,
      'File::DataClass'            => q(0.20.0),
      'HTTP::Message'              => 6.06,
      'IPC::PerlSSH'               => 0.16,
      'LWP'                        => 6.04,
      'Marpa::R2'                  => 2.024000,
      'Moo'                        => 1.002000,
      'MooX::Options'              => 3.83,
      'Plack'                      => 1.0018,
      'TryCatch'                   => 1.003000,
      'Web::Simple'                => 0.020,
   },
   recommends          => {
      'App::cpanminus' => 1.6005 },
   configure_requires  => {
      'version'        => 0.88,
      'Module::Build'  => 0.4004, },
   build_requires      => {
      'version'        => 0.88,
      'Module::Build'  => 0.4004, },
} )->create_build_script; # Goal!

# Local Variables:
# eval: (load-project-state "app-mcp")
# mode: perl
# tab-title: MCP
# tab-width: 3
# End:
