package App::MCP::Log::Result::ViewApache;

use HTML::StateTable::Constants qw( FALSE NUL SPC TRUE );
use HTML::StateTable::Types     qw( ArrayRef Date HashRef Int Str );
use Type::Utils                 qw( class_type );
use Apache::Log::Parser;
use DateTime::Format::Strptime;
use Moo;

with 'HTML::StateTable::Result::Role';

=pod

=encoding utf-8

=head1 Name

App::MCP::Logfile::Result::ViewApache - Result class for the logfile

=head1 Synopsis

   use App::MCP::Log::Result::ViewApache;

=head1 Description

This class represents a line from a logfile. It parses each line as an Apache
log format

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=item line

Each of these result objects is inflated from this required string, a single
line from a logfile

=cut

has 'line' => is => 'ro', isa => Str, required => TRUE;

=item fields

Each line from the logfile is split on comma to produce this list of fields

=cut

has 'fields' =>
   is      => 'lazy',
   isa     => ArrayRef,
   default => sub {
      my $self   = shift;
      my $line   = $self->line or return [];
      my $parser = Apache::Log::Parser->new( fast => TRUE );
      my $fields = $parser->parse($line);

      return [
         $fields->{datetime},
         $fields->{rhost},
         $fields->{method},
         $fields->{path},
         $fields->{status},
         $fields->{bytes},
         $fields->{referer}
      ];
   };

=item _resultset

=cut

has '_resultset' => is => 'ro', init_arg => 'resultset';

=item timestamp

This L<DateTime> object is parsed from the first two fields of the logfile
line. If no timestamp of the correct format is found the string C<undef> is
returned instead

=cut

has 'timestamp' =>
   is      => 'lazy',
   isa     => Date|Str,
   default => sub {
      my $self = shift;
      my $strp = DateTime::Format::Strptime->new(
         pattern => $self->_timestamp_pattern, time_zone => 'UTC'
      );
      my $value = $self->fields->[0] // NUL;
      my $timestamp = $strp->parse_datetime($value);

      unless ($timestamp) {
         $self->_set_remainder_start(0);
         $timestamp = NUL;
      }

      my $context = $self->_resultset->table->context;

      $timestamp->set_time_zone($context->session->timezone) if $timestamp;

      return $timestamp;
   };

# The expected format of the timestamp on the logfile line
has '_timestamp_pattern' => is => 'ro', isa => Str, default => '%d/%b/%Y:%T %z';

=item ip_address

=cut

has 'ip_address' =>
   is      => 'lazy',
   isa     => Str,
   default => sub { shift->fields->[1] // NUL };

has 'method' =>
   is      => 'lazy',
   isa     => Str,
   default => sub { shift->fields->[2] // NUL };

has 'path' =>
   is      => 'lazy',
   isa     => Str,
   default => sub {
      my $path = shift->fields->[3] // NUL;

      $path = substr($path, 0, 99) . '...' if length $path > 100;

      return $path;
   };

has 'status' =>
   is      => 'lazy',
   isa     => Int,
   default => sub { shift->fields->[4] // NUL };

has 'size' =>
   is      => 'lazy',
   isa     => Int,
   default => sub { shift->fields->[5] // NUL };

has 'referer' =>
   is      => 'lazy',
   isa     => Str,
   default => sub { shift->fields->[6] // NUL };

=item remainder

After the initial positional attributes (see above) have been parsed, join the
remaining fields together with a space. If the remaining fields do not contain
key/value pairs this string is displayed instead as a single column

=cut

has 'remainder' =>
   is      => 'lazy',
   isa     => Str,
   default => sub {
      my $self  = shift;
      my $start = $self->remainder_start;

      return join SPC, grep { defined } splice @{$self->fields}, $start;
   };

=item remainder_start

The index into the C<fields> array at which the initial positional parameters
stop and the list of key/value pairs begins

=cut

has 'remainder_start' =>
   is      => 'ro',
   isa     => Int,
   default => 7,
   writer  => '_set_remainder_start';

# Returns the default if the field is undefined. Returns the field value if
# the field matches the supplied key. Returns the field value otherwise
sub _field_value {
   my ($field, $key, $default) = @_;

   return $default unless defined $field;

   return $1 if $field =~ m{ \A $key : (.*) \z }mx;

   return $field;
}

use namespace::autoclean;

1;

__END__

=back

=head1 Subroutines/Methods

=head1 Diagnostics

=head1 Dependencies

=over 3

=item L<DateTime::Format::Strptime>

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
