package App::MCP::JobServer;

use App::Job::Daemon; our $VERSION = App::Job::Daemon->VERSION;

use Class::Usul::Cmd::Constants qw( TRUE );
use Class::Usul::Cmd::Types     qw( LoadableClass );
use Type::Utils                 qw( class_type );
use Moo;

extends 'App::Job::Daemon';

with 'App::MCP::Role::Config';
with 'App::MCP::Role::Log';

has 'lock' =>
   is      => 'lazy',
   isa     => class_type('IPC::SRLock'),
   default => sub { $_[0]->_lock_class->new(builder => $_[0]) };

has '_lock_class' =>
   is      => 'lazy',
   isa     => LoadableClass,
   coerce  => TRUE,
   default => 'IPC::SRLock';

use namespace::autoclean;

1;
