package App::MCP::Model::Form;

use namespace::sweep;

use Moo;
use Class::Usul::Constants;
use Class::Usul::Functions qw( throw );
use HTTP::Status           qw( HTTP_OK );

extends q(App::MCP);
with    q(App::MCP::Role::CommonLinks);
with    q(App::MCP::Role::JavaScript);
with    q(App::MCP::Role::PageConfiguration);
with    q(App::MCP::Role::Preferences);

sub exception_handler {
   my ($self, $req, $e) = @_;

   my $stash = $self->get_stash( $req, { code    => $e->rv,
                                         message => "${e}",
                                         title   => 'Exception Handler' } );

   $stash->{template} = 'exception';
   return $stash;
}

sub get_stash {
   my ($self, $req, $args) = @_;

   return { code => HTTP_OK, page => $self->load_page( $req, $args ) };
}

sub load_page {
   my ($self, $req, $args) = @_; return $args;
}

sub state_diagram {
   return $_[ 0 ]->get_stash( $_[ 1 ], { title => 'State Diagram' } );
}

1;

__END__

=pod

=encoding utf8

=head1 Name

App::MCP::Model::Form - One-line description of the modules purpose

=head1 Synopsis

   use App::MCP::Model::Form;
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
