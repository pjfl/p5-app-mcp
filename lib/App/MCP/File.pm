package App::MCP::File;

use App::MCP::Constants    qw( EXCEPTION_CLASS FALSE NUL TRUE );
use File::DataClass::Types qw( Directory Path );
use HTML::StateTable::Util qw( escape_formula );
use Unexpected::Functions  qw( throw );
use Moo;

with 'App::MCP::Role::CSVParser';

has 'home' => is => 'ro', isa => Directory, required => TRUE;

has 'share' => is => 'ro', isa => Path, required => TRUE;

sub add_meta {
   my ($self, $default_owner, $basedir, $filename, $args) = @_;

   $args //= {};
   $args->{owner} //= $default_owner;
   $args->{shared} //= FALSE;
   $self->csv_parser->combine(
      escape_formula $filename, $args->{owner}, $args->{shared}
   );

   my $mdir  = $self->directory($basedir);
   my $dfile = $mdir->catfile('.directory');

   $dfile->appendln($self->csv_parser->string);
   $dfile->flush;
   return;
}

sub directory {
   my ($self, $basedir) = @_;

   return $self->home unless $basedir;

   return $self->home->catdir($self->to_path($basedir));
}

sub get_files { # Unused
   my ($self, $extensions) = @_;

   my $home     = $self->home->clone;
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

sub get_csv_header {
   my ($self, $selected) = @_;

   $selected = $self->to_path($selected);

   my $file = $self->directory->child($selected);

   return [] unless $file->exists;

   my $line = $file->utf8->head(1);

   $line = substr $line, 1 if ord(substr $line, 0, 1) == 65279; # Remove BOM
   $line = substr $line, 1 if substr $line, 0, 1 eq '#';

   $self->csv_parser->parse($line);

   return [ map { { name => $_ } } $self->csv_parser->fields ];
}

sub get_owner {
   my ($self, $basedir, $filename) = @_;

   my $mdir = $self->directory($basedir);
   my $meta = $self->_get_meta($mdir, $filename);

   return $meta ? $meta->{owner} : NUL;
}

sub get_shared {
   my ($self, $basedir, $filename) = @_;

   my $mdir = $self->directory($basedir);
   my $meta = $self->_get_meta($mdir, $filename);

   return $meta ? $meta->{shared} : NUL;
}

sub move {
   my ($self, $default_owner, $basedir, $from, $filename) = @_;

   my $meta = $self->_get_meta($from->parent, $from->basename);

   $self->_remove_meta($from);
   $self->add_meta($default_owner, $basedir, $filename, $meta);
   return;
}

sub scrub {
   my ($self, $filename) = @_;

   $filename =~ s{ \A [\./]+ | [\./]+ \z }{}gmx;

   return $filename;
}

sub set_shared {
   my ($self, $default_owner, $basedir, $filename, $value) = @_;

   my $mdir  = $self->directory($basedir);
   my $meta  = $self->_get_meta($mdir, $filename);
   my $file  = $mdir->catfile($filename);

   $meta->{shared} = $value ? TRUE : FALSE;
   $self->_remove_meta($file);
   $self->add_meta($default_owner, $basedir, $filename, $meta);
   return $value;
}

sub share_file {
   my ($self, $path) = @_;

   my $linkpath = $self->_get_linkpath($path);

   $linkpath->assert_filepath;
   symlink $path->as_string, $linkpath->as_string;
   return;
}

sub to_path {
   my ($self, $uri_arg) = @_; return _to_path($uri_arg);
}

sub to_uri {
   my ($self, @args) = @_; return _to_uri(join '!', grep { $_ } @args);
}

sub unshare_file {
   my ($self, $path) = @_;

   my $linkpath = $self->_get_linkpath($path);

   return unless $linkpath->exists;

   my $sharedir = $self->share;
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
sub _fields {
   my ($self, $line) = @_;

   $self->csv_parser->parse($line);

   my @fields = $self->csv_parser->fields;

   return {
      name   => $fields[0],
      owner  => $fields[1],
      shared => $fields[2]
   };
}

my $cache = {};

sub _get_meta {
   my ($self, $mdir, $filename) = @_;

   my $dfile = $mdir->catfile('.directory');
   my $meta  = {};

   return unless $dfile->exists;

   my $mtime = $dfile->stat->{mtime};
   my $dname = $mdir->as_string;

   return $cache->{$dname}->{$filename} if exists $cache->{$dname}
       && $mtime == $cache->{$dname}->{_mtime};

   for my $line ($dfile->getlines) {
      my $fields = { %{$self->_fields($line)} };
      my $name   = delete $fields->{name};

      $meta->{$name} = $fields;
   }

   $meta->{_mtime} = $mtime;
   $cache->{$dname} = $meta;

   return $meta->{$filename};
}

sub _get_linkpath {
   my ($self, $path) = @_;

   my $sharedir = $self->share;
   my $relpath  = $path->abs2rel($self->directory);

   return $sharedir->catfile($relpath);
}

sub _remove_meta {
   my ($self, $from) = @_;

   my $dfile = $from->parent->catfile('.directory');

   return unless $dfile->exists;

   my $lines = join NUL, grep {
      my $fields = $self->_fields($_);

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

__END__

=pod

=encoding utf-8

=head1 Name

App::MCP::File - Interface between web application and file system

=head1 Synopsis

   use App::MCP::File;

=head1 Description

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=back

=head1 Subroutines/Methods

=head1 Diagnostics

=head1 Dependencies

=over 3

=item L<Moo>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module. Please report problems to
http://rt.cpan.org/NoAuth/Bugs.html?Dist=App-MCP.
Patches are welcome

=head1 Acknowledgements

Larry Wall - For the Perl programming language

=head1 Author

Peter Flanigan, C<< <pjfl@cpan.org> >>

=head1 License and Copyright

Copyright (c) 2025 Peter Flanigan. All rights reserved

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
# vim: expandtab shiftwidth=3:
