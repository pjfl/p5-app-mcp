# @(#)Ident: Schedule.pm 2014-01-19 02:21 pjf ;

package App::MCP::Model::Schedule;

use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 12 $ =~ /\d+/gmx );

use Moo;
use Class::Usul::Constants;
use Class::Usul::Functions  qw( throw );
use HTTP::Status            qw( HTTP_OK );

extends q(App::MCP);
with    q(App::MCP::Role::CommonLinks);
with    q(App::MCP::Role::PageConfiguration);
with    q(App::MCP::Role::Preferences);

sub get_stash {
   my ($self, $req, $page) = @_;

   return { code => HTTP_OK, page => $self->load_page( $req, $page ) };
}

sub load_page {
   my ($self, $req, $page) = @_;

   my $title = join SPC, map { ucfirst } split m{ _ }mx, $page;

   return { title => $title };
}

sub state_diagram {
   my ($self, $req) = @_; return $self->get_stash( $req, 'state_diagram' );
}

1;

__END__

=pod

=encoding utf8

=head1 Name

App::MCP::Model::Schedule - One-line description of the modules purpose

=head1 Synopsis

   use App::MCP::Model::Schedule;
   # Brief but working code examples

=head1 Version

This documents version v0.1.$Rev: 12 $ of L<App::MCP::Model::Schedule>

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
