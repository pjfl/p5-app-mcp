package App::MCP::File::Result::List;

use HTML::StateTable::Constants qw( FALSE TRUE );
use File::DataClass::Types      qw( Directory File );
use HTML::StateTable::Types     qw( Date Int Str );
use Type::Utils                 qw( class_type );
use DateTime;
use Moo;

with 'HTML::StateTable::Result::Role';

has 'directory' => is => 'ro', isa => Directory, required => TRUE;

has 'extension' => is => 'ro', isa => Str, predicate => 'has_extension';

has 'icon' =>
   is      => 'lazy',
   isa     => Str,
   default => sub { shift->type };

has 'modified' =>
   is      => 'lazy',
   isa     => Date,
   default => sub {
      my $self     = shift;
      my $context  = $self->table->context;
      my $dt       = DateTime->from_epoch(
         epoch     => $self->path->stat->{mtime},
         time_zone => $context->config->local_tz
      );

      $dt->set_time_zone($context->session->timezone);
      return $dt;
   };

has 'name' =>
   is      => 'lazy',
   isa     => Str,
   default => sub {
      my $self = shift;
      my $name = $self->path->clone->relative($self->directory);

      return "${name}";
   };

has 'owner' =>
   is      => 'lazy',
   isa     => Str,
   default => sub { shift->path->stat->{uid} };

has 'path' =>
   is       => 'ro',
   isa      => File|Directory,
   coerce   => TRUE,
   required => TRUE;

has 'size' =>
   is      => 'lazy',
   isa     => Int,
   default => sub { shift->path->stat->{size} };

has 'table' => is => 'ro', weak_ref => TRUE;

has 'type' =>
   is      => 'lazy',
   isa     => Str,
   default => sub {
      my $self = shift;
      my $path = $self->path;

      return $path->is_file ? 'file' : $path->is_dir ? 'directory' : 'other';
};

has 'uri_arg' =>
   is      => 'lazy',
   isa     => Str,
   default => sub {
      my $self = shift;

      (my $name = $self->name) =~ s{ / }{!}gmx;

      return $name;
   };

use namespace::autoclean;

1;
