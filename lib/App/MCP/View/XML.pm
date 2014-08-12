package App::MCP::View::XML;

use namespace::sweep;

use Moo;
use Class::Usul::Types qw( Object );
use Encode             qw( encode );
use XML::Simple;

with q(App::MCP::Role::Component);
with q(App::MCP::Role::FormHandler);

has '+moniker' => default => 'xml';

# Private attributes
has '_transcoder' => is => 'lazy', isa => Object,
   builder        => sub { XML::Simple->new };

# Public methods
sub serialize {
   my ($self, $req, $stash) = @_;

   my $content = { items => $stash->{form}->[ 0 ]->{fields} };
   my $js      = join "\n", @{ $stash->{page}->{literal_js} || [] };
   my $meta    = $stash->{page}->{meta} // {};

   $content->{ $_ } = $meta->{ $_ } for (keys %{ $meta });

   $js and $content->{script} //= [] and push @{ $content->{script} }, $js;
   $content = encode( 'UTF-8', $self->_transcoder->xml_out( $content ) );

   return [ $stash->{code}, __header( $stash->{http_headers} ), [ $content ] ];
}

# Private functions
sub __header {
   return [ 'Content-Type' => 'text/xml', @{ $_[ 0 ] || [] } ];
}

1;

__END__

=pod

=encoding utf8

=head1 Name

App::MCP::View::XML - One-line description of the modules purpose

=head1 Synopsis

   use App::MCP::View::XML;
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

=item L<Class::Usul>

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

Copyright (c) 2014 Peter Flanigan. All rights reserved

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
