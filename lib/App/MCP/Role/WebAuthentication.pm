package App::MCP::Role::WebAuthentication;

use attributes ();
use namespace::sweep;

use Class::Usul::Constants;
use Class::Usul::Functions qw( is_member throw );
use HTTP::Status           qw( HTTP_FORBIDDEN HTTP_NOT_FOUND );
use Scalar::Util           qw( blessed );
use Moo::Role;

requires qw( execute );

around 'execute' => sub {
   my ($orig, $self, $method, $req) = @_; my $class = blessed $self || $self;

   $self->can( $method )
      or throw error => 'Class [_1] has no method [_2]',
               args  => [ $class, $method ], rv => HTTP_NOT_FOUND;

   my $method_roles = $self->_list_roles_of( $method );

   $method_roles->[ 0 ]
      or throw error => 'Method [_1] is private',
               args  => [ $method ], rv => HTTP_FORBIDDEN;

   is_member 'any', $method_roles and return $orig->( $self, $method, $req );

   my $sess = $req->session;

   unless (exists $sess->{user_name} and $sess->{user_name} ne 'unknown') {
      my $location = $req->uri_for( 'login' );
      my $message  = [ 'Authentication required' ];

      return { redirect => { location => $location, message => $message } };
   }

   for my $role_name (@{ $sess->{user_roles} }) {
      is_member $role_name, $method_roles
         and return $orig->( $self, $method, $req );
   }

   throw error => 'User [_1] permission denied',
         args  => [ $sess->{user_name} ], rv => HTTP_FORBIDDEN;
   return; # Never reached
};

sub _list_roles_of {
   my ($self, $method) = @_; my $class = blessed $self || $self;

   my $code_ref = $class->can( $method ) or return ();

   return [ map  { m{ \A Role [\(] ([^\)]+) [\)] \z }mx }
            grep { m{ \A Role }mx } @{ attributes::get( $code_ref ) || [] } ];
}

1;

__END__

=pod

=encoding utf8

=head1 Name

App::MCP::Role::WebAuthentication - One-line description of the modules purpose

=head1 Synopsis

   use App::MCP::Role::WebAuthentication;
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
