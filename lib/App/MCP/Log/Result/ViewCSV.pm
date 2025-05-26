package App::MCP::Log::Result::ViewCSV;

use HTML::StateTable::Constants qw( FALSE NUL SPC TRUE );
use HTML::StateTable::Types     qw( ArrayRef Date HashRef Int Str );
use Type::Utils                 qw( class_type );
use DateTime::Format::Strptime;
use Moo;

with 'HTML::StateTable::Result::Role';
with 'App::MCP::Role::CSVParser';

=pod

=encoding utf-8

=head1 Name

App::MCP::Logfile::Result::ViewCSV - Result class for the logfile

=head1 Synopsis

   use App::MCP::Log::Result::ViewCSV;

=head1 Description

This class represents a line from a logfile. It parses each line as a comma
separated list of fields

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
      my $self = shift;
      my $line = $self->line or return [];

      $self->csv_parser->parse($line);

      my @fields = ($self->csv_parser->fields);

      return \@fields;
   };

=item field_map

Some of the fields in this result contain key/value pairs separated by a colon.
Split them out to create this hash reference. Unused

=cut

has 'field_map' =>
   is      => 'lazy',
   isa     => HashRef,
   default => sub {
      my $self      = shift;
      my $index     = $self->remainder_start or return {};
      my $field_map = {};

      while (defined(my $field = $self->fields->[$index++])) {
         next unless $field =~ m{ \A [^:]+ : .* \z }mx;

         my ($key, $value) = split m{ : }mx, $field, 2;

         $value =~ s{ (?: \A \" | \" \z ) }{}gmx
            if defined $value && length $value;

         $value = undef if $value =~ m{ \A [\<]? undef [\>]? \z }mx;

         $field_map->{$key} = $value;
      }

      return $field_map;
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
has '_timestamp_pattern' => is => 'ro', isa => Str, default => '%Y/%m/%d %T';

=item status

An enumerated field (string) that represents status of the logfile line

=cut

has 'status' =>
   is      => 'lazy',
   isa     => Str,
   default => sub {
      my $self = shift;

      return NUL unless $self->remainder_start;

      return $self->fields->[1] // NUL;
   };

has 'status_filter' =>
   is      => 'ro',
   isa     => ArrayRef[Str],
   default => sub {
      return [ qw(cut -f 2 -d), q(,), qw(| tr -d \" | sort | uniq) ];
   };

# has 'status_filter_values' =>
#    is      => 'ro',
#    isa     => ArrayRef[Str],
#    default => sub {
#       return [ qw(ALERT CRITICAL DEBUG ERROR FATAL INFO WARNING) ];
#    };

=item username

Name of user causing this log entry

=cut

has 'username' =>
   is      => 'lazy',
   isa     => Str,
   default => sub {
      my $self = shift;

      return NUL unless $self->remainder_start;

      return $self->fields->[2] // NUL;
   };

has 'username_filter' =>
   is      => 'ro',
   isa     => ArrayRef[Str],
   default => sub {
      return [ qw(cut -f 3 -d), q(,), qw(| tr -d \" | sort | uniq) ];
   };

=item source

Code responsible for creating this line

=cut

has 'source' =>
   is      => 'lazy',
   isa     => Str,
   default => sub {
      my $self = shift;

      return NUL unless $self->remainder_start;

      my $source = $self->fields->[3] // NUL;

      $source =~ s{ \[ \d+ \] \z }{}mx;

      return $source;
   };

has 'source_filter' =>
   is      => 'ro',
   isa     => ArrayRef[Str],
   default => sub {
      return [ qw(cut -f 4 -d), q(,), qw(| tr -d \" | cut -f 1 -d), q([),
               qw(| sort | uniq) ];
   };

=item pid

The operating system id (integer) of the process that created this logfile line

=cut

has 'pid' =>
   is      => 'lazy',
   isa     => Int,
   default => sub {
      my $self = shift;

      return 0 unless $self->remainder_start;

      my $source = $self->fields->[3] // NUL;

      my ($pid) = $source =~ m{ \[ (\d+) \] \z }mx;

      return $pid || 0;
   };

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
   default => 4,
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
