package App::MCP::Authentication::Realms::DBIC;

use HTML::Forms::Constants qw( EXCEPTION_CLASS FALSE TRUE );
use HTML::Forms::Types     qw( Str );
use Scalar::Util           qw( blessed );
use Type::Utils            qw( class_type );
use Unexpected::Functions  qw( throw Unspecified );
use Moo;

with 'App::MCP::Role::UpdatingSession';

=pod

=encoding utf-8

=head1 Name

App::MCP::Authentication::Realms::DBIC - Authenticate with a DBIC user object

=head1 Synopsis

   use App::MCP::Authentication::Realms::DBIC;

=head1 Description

Authenticate with a L<DBIx::Class> user object

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=item C<authenticate_method>

Defaults to C<authenticate>. The name of the method on the user object which
will perform the actual authentication. The C<authenticate> method in this
class is only a proxy

=cut

has 'authenticate_method' => is => 'ro', isa => Str, default => 'authenticate';

=item C<find_user_method>

Defaults to C<find_by_key>. The name of the method on the user resultset
used to find a user object

=cut

has 'find_user_method' => is => 'ro', isa => Str, default => 'find_by_key';

=item C<realm>

A required string. The name of the authentication realm

=cut

has 'realm' => is => 'ro', isa => Str, required => TRUE;

=item C<result_class>

The L<result class|DBIx::Class::Core> name for the user object. Defaults to
C<User>

=cut

has 'result_class' => is => 'ro', isa => Str, default => 'User';

=item C<schema>

A required instance of L<DBIx::Class::Schema>

=cut

has 'schema' =>
   is       => 'ro',
   isa      => class_type('DBIx::Class::Schema'),
   required => TRUE;

=item C<validate_ip_method>

Defaults to C<validate_address>

=cut

has 'validate_ip_method' =>
   is      => 'ro',
   isa     => Str,
   default => 'validate_address';

=back

=head1 Subroutines/Methods

Defines the following methods;

=over 3

=item C<find_user>

   $user_object = $self->find_user($args);

Finds a user object from the username/userid/email provided

The C<args> hash reference keys are;

=over 3

=item username

The name of the user to find. Can be a user ID, a user name, or an email
address. Required

=item options

An optional hash reference of additional options passed the find user method on
the resultset

Will add C<< prefetch => 'role' >> if no other C<prefetch> has been set

=back

Calls C<resultset>.C<$find_user_method> to get the user object

Returns a L<user object|DBIx::Class::Core> or undefined if not found

=cut

sub find_user {
   my ($self, $args) = @_;

   my $rs      = $self->schema->resultset($self->result_class);
   my $method  = $self->find_user_method;
   my $options = $args->{options} // {};

   $options->{prefetch} = 'role' unless exists $options->{prefetch};

   return $rs->$method($args->{username}, $options);
}

=item C<authentcate>

   $bool = $self->authenticate($args);

Authenticates the supplied claim

The C<args> hash reference keys are;

=over 3

=item address

This IP address of the originating request. Optional

=item code

OTP code. If 2FA is enabled this is required otherwise it is not necessary

=item password

User supplied password being validated. Required

=item user

A user object. Returned by calling C<find_user>

=back

Calls C<user>.C<$authenticate_method> to authenticate the user. Calls
C<user>.C<$validate_ip_method> to validate the user's IP address

Returns C<TRUE> if successful, raises an exception otherwise

=cut

sub authenticate {
   my ($self, $args) = @_;

   throw Unspecified, ['user'] unless $args->{user};

   my $user   = $args->{user};
   my $method = $self->validate_ip_method;

   $user->$method($args->{address}) if $args->{address} && $user->can($method);

   $method = $self->authenticate_method;
   $user->$method($args->{password}, $args->{code});
   return TRUE;
}

=item C<to_session>

   $self->to_session($args);

Copies the attribute values of the user object to the session object if
matching attribute names are found

The C<args> hash reference keys are;

=over 3

=item address

The IP address of the originating request. Optional

=item session

The user's session object. Required

=item user

A user object. Returned by calling C<find_user>

=back

=cut

sub to_session {
   my ($self, $args) = @_;

   my $session = $args->{session};

   return unless $session && blessed $session;

   $session->realm($self->realm) if $session->can('realm');

   my $user = $args->{user} or return;

   $self->update_session($session, $user->profile_value);

   $session->address($args->{address})
      if $session->can('address') && $args->{address};

   $session->email($user->email)          if $session->can('email');
   $session->id($user->id)                if $session->can('id');
   $session->role($user->role->role_name) if $session->can('role');
   $session->username($user->user_name)   if $session->can('username');

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

There are no known bugs in this module. Please report problems to
http://rt.cpan.org/NoAuth/Bugs.html?Dist=App::MCP.
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
