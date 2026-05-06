package App::MCP::Response;

use App::MCP::Constants qw( NUL );
use Unexpected::Types   qw( ArrayRef );
use Moo;

=pod

=head1 Name

App::MCP::Response - Response object

=head1 Synopsis

   use App::MCP::Response;

=head1 Description

Response object

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=item C<body>

=cut

has 'body' => is => 'rw';

has '_headers' => is => 'ro', isa => ArrayRef, default => sub { [] };

=back

=head1 Subroutines/Methods

Defines the following methods;

=over 3

=item C<header>

=cut

sub header {
   my ($self, @header) = @_;

   push @{$self->_headers}, @header;

   return wantarray ? @{$self->_headers} : $self->_headers;
}

=item C<write>

=cut

sub write {
   my ($self, $content) = @_;

   my $body = $self->body // NUL;

   $self->body($body . $content);
   return;
}

use namespace::autoclean;

1;

__END__

=back

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Moo>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module.
Please report problems to the address below.
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
