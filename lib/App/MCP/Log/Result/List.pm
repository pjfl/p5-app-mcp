package App::MCP::Log::Result::List;

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

      return $self->path->clone->relative($self->directory)->as_string;
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

__END__

=pod

=encoding utf-8

=head1 Name

App::MCP::Logfile::List::Result - Music Catalog

=head1 Synopsis

   use App::MCP::Logfile::List::Result;
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

=item L<DateTime>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module. Please report problems to
http://rt.cpan.org/NoAuth/Bugs.html?Dist=App::MCP.
Patches are welcome

=head1 Acknowledgements

Larry Wall - For the Perl programming language

=head1 Author

Peter Flanigan, C<< <lazarus@roxsoft.co.uk> >>

=head1 License and Copyright

Copyright (c) 2023 Peter Flanigan. All rights reserved

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
