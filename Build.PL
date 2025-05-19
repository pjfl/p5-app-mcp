# Build.PL is generated - do not edit
use strict;
use warnings;

use Module::Build 0.4004;
use File::Spec::Functions qw( catdir );

my $perl_ver = 5.010001;
my $name     = 'App-MCP'; $name =~ s{ - }{::}gmx;
my $prereqs  = {
  'build_requires' => {
    'Module::Build' => '0.4004',
    'version' => '0.88'
  },
  'configure_requires' => {
    'Module::Build' => '0.4004',
    'version' => '0.88'
  },
  'recommends' => {
    'DBD::mysql' => '4.028',
    'Starman' => '0.4009',
    'Twiggy' => '0.1024'
  },
  'requires' => {
    'Algorithm::Cron' => '0.10',
    'App::Job' => 'v0.1.1',
    'App::MCP::Worker' => 'v0.2.0',
    'Async::IPC' => 'v0.1.36',
    'Auth::GoogleAuth' => '1.05',
    'Class::C3::Componentised' => '1.001000',
    'Class::Usul::Cmd' => 'v0.1.14',
    'Class::Workflow' => '0.11',
    'Crypt::Eksblowfish' => '0.009',
    'Crypt::SRP' => '0.019',
    'DBIx::Class' => '0.08204',
    'DBIx::Class::Helpers' => '2.036000',
    'DBIx::Class::InflateColumn::Object::Enum' => '0.06',
    'DBIx::Class::Moo::ResultClass' => '0.001001',
    'DBIx::Class::TimeStamp' => '0.14',
    'Daemon::Control' => '0.001006',
    'Data::Page' => '2.03',
    'Data::Record' => '0.02',
    'Data::Validation' => 'v0.28.1',
    'DateTime' => '1.65',
    'DateTime::Format::Human' => '0.01',
    'DateTime::Format::Strptime' => '1.79',
    'DateTime::TimeZone' => '2.57',
    'EV' => '4.34',
    'Exporter::Tiny' => '1.006000',
    'File::DataClass' => 'v0.73.0',
    'Format::Human::Bytes' => '0.06',
    'HTML::Forms' => 'v0.1.76',
    'HTML::Forms::Model::DBIC' => 'v0.1.6',
    'HTML::Parser' => '3.76',
    'HTML::StateTable' => 'v0.2.7',
    'HTML::Tiny' => '1.08',
    'HTTP::Message' => '6.44',
    'IPC::PerlSSH' => '0.17',
    'JSON::MaybeXS' => '1.004004',
    'MIME::Types' => '2.24',
    'Marpa::R2' => '12.000000',
    'Math::BigInt::GMP' => '1.38',
    'Moo' => '2.005005',
    'MooX::HandlesVia' => '0.001009',
    'Plack' => '1.0050',
    'Plack::Middleware::Debug' => '0.16',
    'Plack::Middleware::Session' => '0.33',
    'Pod::Markdown::Github' => '0.04',
    'Redis' => '2.000',
    'Ref::Util' => '0.204',
    'Sub::Install' => '0.929',
    'Text::CSV_XS' => '1.56',
    'Text::MultiMarkdown' => '1.000035',
    'Try::Tiny' => '0.31',
    'Type::Tiny' => '2.002001',
    'URI' => '5.17',
    'Unexpected' => 'v1.0.1',
    'Web::Components' => 'v0.13.1',
    'Web::Components::Role::Email' => 'v0.3.4',
    'Web::Components::Role::TT' => 'v0.8.3',
    'Web::ComposableRequest' => 'v0.21.1',
    'Web::Simple' => '0.033',
    'local::lib' => '2.000012',
    'namespace::autoclean' => '0.29',
    'perl' => '5.010001',
    'strictures' => '2.000006'
  },
  'test_requires' => {
    'File::Spec' => '0',
    'Module::Build' => '0.4004',
    'Module::Metadata' => '0',
    'Sys::Hostname' => '0',
    'Test::Requires' => '0.06',
    'version' => '0.88'
  },
};
my $testing  = sub { $ENV{AUTOMATED_TESTING}
                  || $ENV{PERL_CPAN_REPORTER_CONFIG}
                  || $ENV{PERL5_CPANPLUS_IS_VERSION} };
my $whimper  = sub { print {*STDOUT} $_[ 0 ]."\n"; exit 0 };
my $stop     = sub {
   $testing->() or $whimper->( $_[ 0 ] );
   $prereqs->{build_requires} = { %{ $prereqs->{configure_requires} } };
   $prereqs->{test_requires } = { %{ $prereqs->{configure_requires} } };
   $prereqs->{test_requires }->{ 'Test::Requires' } = 0.06;
   delete $prereqs->{requires};
};

# Not interested in reports below min perl ver
$] < $perl_ver and $stop->( "Minimum required Perl version is ${perl_ver}" );

my $bob = Module::Build->subclass( code => do { local $/; <DATA> } )->new(
   'add_to_cleanup' => [ 'debian', 'META.yml' ],
   'module_name'    => $name,
   'notes'          => { min_perl_version => $perl_ver,
                         testing          => $testing->() },
   %{ $prereqs },

);

$bob->install_path( 'bin'    => catdir( $bob->install_base, 'bin'   ) );
$bob->install_path( 'lib'    => catdir( $bob->install_base, 'lib'   ) );
$bob->install_path( 'var'    => catdir( $bob->install_base, 'var'   ) );
$bob->install_path( 'local'  => catdir( $bob->install_base, 'local' ) );
$bob->install_path( 'script' => catdir( $bob->install_base, 'bin'   ) );
$bob->install_path( 'bindoc' => catdir( $bob->install_base, 'man', 'man1' ) );
$bob->install_path( 'libdoc' => catdir( $bob->install_base, 'man', 'man3' ) );
$bob->add_build_element( 'config' );
$bob->add_build_element( 'local'  );
$bob->add_build_element( 'var'    );
$bob->create_build_script;
exit 0;

__DATA__

use File::Basename        qw( dirname );
use File::Copy            qw( copy );
use File::Find            qw( find );
use File::Path            qw( make_path );
use File::Spec::Functions qw( catdir catfile );

sub ACTION_install {
   my $self = shift; umask oct '0007'; $self->SUPER::ACTION_install();

   for my $dir (qw( logs run tmp )) {
      my $path = catdir( $self->install_path( 'var' ), $dir );

      $self->destdir and $path = catdir( $self->destdir, $path );
      -d $path or make_path( $path, { mode => oct '0770' } );
   }

   return;
}

sub process_config_files {
   my $self     = shift; umask oct '0027';
   my $distname = $self->dist_name;
   my $home     = catdir( 'lib', split m{ - }mx, $distname);

   return $self->_process_files( catfile( $home, (lc $distname).'.json' ) );
}

sub process_local_files {
   my $self = shift; return $self->_process_files( 'local' );
}

sub process_var_files {
   my $self = shift; my $pattern; umask oct '0027';

   for (qw( .git logs run tmp )) {
      $pattern .= ($pattern ? '|' : q()).(catdir( q(), $_ ));
   }

   $self->_skip_pattern( qr{ (?: $pattern ) }mx );
   return $self->_process_files( 'var' );
}

sub _process_files {
   # Find and copy files and directories from source tree to destination tree
   my ($self, $src, $dest) = @_; $src or return; $dest ||= 'blib';

   if    (-f $src) { $self->_copy_file( $src, $dest ) }
   elsif (-d $src) {
      my $prefix = $self->base_dir;

      find( { no_chdir => TRUE, wanted => sub {
         (my $path = $File::Find::name) =~ s{ \A $prefix }{}mx;
         return $self->_copy_file( $path, $dest );
      }, }, $src );
   }

   return;
}

sub _copy_file {
   my ($self, $src, $dest) = @_; my $pattern = $self->_skip_pattern;

   ($src and -f $src and (not $pattern or $src !~ $pattern)) or return;
   # Rebase the directory path
   my $dir = catdir( $dest, dirname( $src ) );
   # Ensure target directory exists
   -d $dir or make_path( $dir, { mode => oct '0750' } );
   copy( $src, $dir );
   return;
}

sub _skip_pattern { # Accessor/mutator for the regex of paths not to process
   return defined $_[ 1 ] ? $_[ 0 ]->{_skip_pattern} = $_[ 1 ]
                          : $_[ 0 ]->{_skip_pattern};
}
