package App::MCP::Schema::Schedule::ResultSet::User;

use 5.01;
use strictures;
use parent 'DBIx::Class::ResultSet';

use App::MCP::Constants;
use Class::Usul::Functions qw( throw );
use HTTP::Status           qw( HTTP_NOT_FOUND );

sub find_by_id_or_name {
   my ($self, $arg) = @_; (defined $arg and length $arg) or return; my $user;

   $arg =~ m{ \A \d+ \z }mx and $user = $self->find( $arg );
   $user or $user = $self->find_by_name( $arg );
   return $user;
}

sub find_by_name {
   my ($self, $user_name) = @_;

   my $user = $self->search( { username => $user_name } )->single
      or throw error => 'User [_1] unknown',
               args  => [ $user_name ], rv => HTTP_NOT_FOUND;

   return $user;
}

sub load_factor {
   return 14;
}

1;

__END__

=pod

=encoding utf8

=head1 Name

App::MCP::Schema::Schedule::ResultSet::User - One-line description of the modules purpose

=head1 Synopsis

   use App::MCP::Schema::Schedule::ResultSet::User;
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
