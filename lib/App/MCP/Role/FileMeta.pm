package App::MCP::Role::FileMeta;

use HTML::StateTable::Constants qw( EXCEPTION_CLASS FALSE NUL TRUE );
use HTML::StateTable::Types     qw( Str );
use HTML::StateTable::Util      qw( escape_formula );
use Unexpected::Functions       qw( throw );
use Moo::Role;

requires qw( meta_home meta_share );

with 'App::MCP::Role::CSVParser';

sub meta_directory {
   my ($self, $basedir) = @_;

   return $self->meta_home unless $basedir;

   return $self->meta_home->catdir($self->meta_to_path($basedir));
}

sub meta_get_files { # Unused
   my ($self, $extensions) = @_;

   my $home     = $self->meta_home->clone;
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

sub meta_get_csv_header {
   my ($self, $selected) = @_;

   $selected = $self->meta_to_path($selected);

   my $file = $self->meta_directory->child($selected);

   return [] unless $file->exists;

   my $line = $file->utf8->head(1);

   $line = substr $line, 1 if ord(substr $line, 0, 1) == 65279; # Remove BOM
   $line = substr $line, 1 if substr $line, 0, 1 eq '#';
   $self->csv_parser->parse($line);

   my @fields = $self->csv_parser->fields;

   return [ map { { name => $_ } } @fields ];
}

sub meta_get_owner {
   my ($self, $basedir, $filename) = @_;

   my $mdir = $self->meta_directory($basedir);
   my $meta = $self->_meta_get($mdir)->{$filename};

   return $meta ? $meta->{owner} : NUL;
}

sub meta_get_shared {
   my ($self, $basedir, $filename) = @_;

   my $mdir = $self->meta_directory($basedir);
   my $meta = $self->_meta_get($mdir)->{$filename};

   return $meta ? $meta->{shared} : NUL;
}

sub meta_move {
   my ($self, $default_owner, $basedir, $from, $filename) = @_;

   my $meta = $self->_meta_get($from->parent)->{$from->basename};

   $self->_meta_remove($from);
   $self->_meta_add($default_owner, $basedir, $filename, $meta);
   return;
}

sub meta_scrub {
   my ($self, $filename) = @_;

   $filename =~ s{ \A [\./]+ | [\./]+ \z }{}gmx;

   return $filename;
}

sub meta_set_shared {
   my ($self, $default_owner, $basedir, $filename, $value) = @_;

   my $mdir  = $self->meta_directory($basedir);
   my $meta  = $self->_meta_get($mdir)->{$filename};
   my $file  = $mdir->catfile($filename);

   $meta->{shared} = $value ? TRUE : FALSE;
   $self->_meta_remove($file);
   $self->_meta_add($default_owner, $basedir, $filename, $meta);
   return $value;
}

sub meta_share_file {
   my ($self, $path) = @_;

   my $linkpath = $self->_meta_get_linkpath($path);

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

sub meta_unshare_file {
   my ($self, $path) = @_;

   my $linkpath = $self->_meta_get_linkpath($path);

   return unless $linkpath->exists;

   my $sharedir = $self->meta_share;
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
sub _meta_add {
   my ($self, $default_owner, $basedir, $filename, $args) = @_;

   $args //= {};
   $args->{owner} //= $default_owner;
   $args->{shared} //= FALSE;
   $self->csv_parser->combine(
      escape_formula $filename, $args->{owner}, $args->{shared}
   );

   my $mdir  = $self->meta_directory($basedir);
   my $dfile = $mdir->catfile('.directory');

   $dfile->appendln($self->csv_parser->string);
   $dfile->flush;
   return;
}

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

sub _meta_get_linkpath {
   my ($self, $path) = @_;

   my $sharedir = $self->meta_share;
   my $relpath  = $path->abs2rel($self->meta_directory);

   return $sharedir->catfile($relpath);
}

sub _meta_remove {
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

# Private functions
sub _to_path {
   my $path = shift; $path =~ s{ ! }{/}gmx if defined $path; return $path;
}

sub _to_uri {
   (my $uri = shift) =~ s{ / }{!}gmx; return $uri;
}

use namespace::autoclean;

1;
