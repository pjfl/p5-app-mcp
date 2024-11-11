package App::MCP::Role::FileMeta;

use HTML::StateTable::Constants qw( EXCEPTION_CLASS FALSE NUL TRUE );
use HTML::StateTable::Types     qw( Str );
use HTML::StateTable::Util      qw( escape_formula );
use Unexpected::Functions       qw( throw );
use Moo::Role;

with 'App::MCP::Role::CSVParser';

has 'meta_config_attr' => is => 'ro', isa => Str, default => 'filemanager';

sub meta_add {
   my ($self, $context, $basedir, $filename, $args) = @_;

   $args //= {};
   $args->{owner} //= $context->session->username;
   $args->{shared} //= FALSE;
   $self->csv_parser->combine(
      escape_formula $filename, $args->{owner}, $args->{shared}
   );

   my $mdir  = $self->meta_directory($context, $basedir);
   my $dfile = $mdir->catfile('.directory');

   $dfile->appendln($self->csv_parser->string);
   $dfile->flush;
   return;
}

sub meta_directory {
   my ($self, $context, $basedir) = @_;

   my $home = $self->meta_home($context);

   return $home unless $basedir;

   return $home->catdir($self->meta_to_path($basedir));
}

sub meta_get_files { # Unused
   my ($self, $context, $extensions) = @_;

   my $home     = $self->meta_home($context)->clone;
   my $filter   = sub { m{ \. (?: $extensions ) \z }mx };
   my $iterator = $home->deep->filter($filter)->iterator({});
   my $files    = [];

   while (defined (my $item = $iterator->())) {
      my $relpath = $item->abs2rel($home);
      my $label   = $relpath;

      push @{$files}, $label, $relpath;
   }

   return $files;
}

sub meta_get_header {
   my ($self, $context, $selected) = @_;

   $selected = $self->meta_to_path($selected);

   my $file = $self->meta_directory($context)->child($selected);

   return [] unless $file->exists;

   my $line = $file->utf8->head(1);

   $line = substr $line, 1 if ord(substr $line, 0, 1) == 65279; # Remove BOM
   $line = substr $line, 1 if substr $line, 0, 1 eq '#';
   $self->csv_parser->parse($line);

   my @fields = $self->csv_parser->fields;

   return [ map { { name => $_ } } @fields ];
}

sub meta_get_owner {
   my ($self, $context, $basedir, $filename) = @_;

   my $mdir = $self->meta_directory($context, $basedir);
   my $meta = $self->_meta_get($mdir)->{$filename};

   return $meta ? $meta->{owner} : NUL;
}

sub meta_get_shared {
   my ($self, $context, $basedir, $filename) = @_;

   my $mdir = $self->meta_directory($context, $basedir);
   my $meta = $self->_meta_get($mdir)->{$filename};

   return $meta ? $meta->{shared} : NUL;
}

sub meta_home {
   my ($self, $context) = @_;

   return $self->_meta_get_config($context)->{directory};
}

sub meta_move {
   my ($self, $context, $basedir, $from, $filename) = @_;

   my $meta = $self->_meta_get($from->parent)->{$from->basename};

   $self->meta_remove($from);
   $self->meta_add($context, $basedir, $filename, $meta);
   return;
}

sub meta_remove {
   my ($self, $from) = @_;

   my $dfile = $from->parent->catfile('.directory');

   return unless $dfile->exists;

   my $lines = join NUL, grep {
      my $fields = $self->_meta_fields($_);

      $fields->{name} ne $from->basename ? TRUE : FALSE
   } $dfile->getlines;

   $dfile->buffer($lines)->write;
   $dfile->flush;
   return;
}

sub meta_scrub {
   my ($self, $filename) = @_;

   $filename =~ s{ \A [\./]+ | [\./]+ \z }{}gmx;

   return $filename;
}

sub meta_set_shared {
   my ($self, $context, $basedir, $filename, $value) = @_;

   my $mdir = $self->meta_directory($context, $basedir);
   my $meta = $self->_meta_get($mdir)->{$filename};
   my $file = $mdir->catfile($filename);

   $meta->{shared} = $value ? TRUE : FALSE;
   $self->meta_remove($file);
   $self->meta_add($context, $basedir, $filename, $meta);
   return $value;
}

sub meta_share {
   my ($self, $context, $path) = @_;

   my $linkpath = $self->_meta_get_linkpath($context, $path);

   $linkpath->assert_filepath;
   symlink $path->as_string, $linkpath->as_string;
   return;
}

sub meta_to_path {
   my ($self, $uri_arg) = @_; return _to_path($uri_arg);
}

sub meta_to_uri {
   my ($self, @args) = @_; return _to_uri(join '!', grep { $_ } @args);
}

sub meta_unshare {
   my ($self, $context, $path) = @_;

   my $linkpath = $self->_meta_get_linkpath($context, $path);

   return unless $linkpath->exists;

   my $sharedir = $self->_meta_get_config($context)->{sharedir};
   my $dir      = $linkpath->parent;

   $linkpath->unlink;

   while ($dir ne $sharedir) {
      last unless $dir->is_empty;
      $dir->rmdir;
      $dir = $dir->parent;
   }

   return;
}

# Private methods
sub _meta_fields {
   my ($self, $line) = @_;

   $self->csv_parser->parse($line);

   my @fields = $self->csv_parser->fields;

   return {
      name   => $fields[0],
      owner  => $fields[1],
      shared => $fields[2]
   };
}

my $meta_cache = {};

sub _meta_get {
   my ($self, $mdir) = @_;

   my $dfile = $mdir->catfile('.directory');
   my $meta  = {};

   return $meta unless $dfile->exists;

   my $mtime = $dfile->stat->{mtime};
   my $dname = $mdir->as_string;

   return $meta_cache->{$dname} if exists $meta_cache->{$dname}
       && $mtime == $meta_cache->{$dname}->{_mtime};

   for my $line ($dfile->getlines) {
      my $fields = { %{$self->_meta_fields($line)} };
      my $name   = delete $fields->{name};

      $meta->{$name} = $fields;
   }

   $meta->{_mtime} = $mtime;
   $meta_cache->{$dname} = $meta;
   return $meta;
}

sub _meta_get_config {
   my ($self, $context) = @_;

   my $config_attr = $self->meta_config_attr;

   return $context->config->$config_attr()
      if $context->can('config') && $context->config->can($config_attr);

   return $context->$config_attr() if $context->can($config_attr);

   throw 'No file meta configuration found';
}

sub _meta_get_linkpath {
   my ($self, $context, $path) = @_;

   my $sharedir = $self->_meta_get_config($context)->{sharedir};
   my $relpath  = $path->abs2rel($self->meta_directory($context));

   return $sharedir->catfile($relpath);
}

# Private functions
sub _to_path {
   my $path = shift; $path =~ s{ ! }{/}gmx if defined $path; return $path;
}

sub _to_uri {
   (my $uri = shift) =~ s{ / }{!}gmx; return $uri;
}

use namespace::autoclean;

1;
