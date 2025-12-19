package App::MCP::Authentication::Realms::DBIC;

use App::MCP::Constants   qw( EXCEPTION_CLASS FALSE TRUE );
use Unexpected::Types     qw( Str );
use Scalar::Util          qw( blessed );
use Type::Utils           qw( class_type );
use Unexpected::Functions qw( throw Unspecified );
use Moo;

with 'App::MCP::Role::UpdatingSession';

has 'authenticate_method' => is => 'ro', isa => Str, default => 'authenticate';

has 'find_user_method' => is => 'ro', isa => Str, default => 'find_by_key';

has 'realm' => is => 'ro', isa => Str, required => TRUE;

has 'result_class' => is => 'ro', isa => Str, default => 'User';

has 'schema' =>
   is       => 'ro',
   isa      => class_type('DBIx::Class::Schema'),
   required => TRUE;

sub authenticate {
   my ($self, $args) = @_;

   throw Unspecified, ['user'] unless $args->{user};

   my $method = $self->authenticate_method;

   return $args->{user}->$method($args->{password}, $args->{code});
}

sub find_user {
   my ($self, $args) = @_;

   my $rs      = $self->schema->resultset($self->result_class);
   my $method  = $self->find_user_method;
   my $options = $args->{options} // {};

   $options->{prefetch} = 'role' unless exists $options->{prefetch};

   return $rs->$method($args->{username}, $options);
}

sub to_session {
   my ($self, $args) = @_;

   my $session = $args->{session};

   return unless $session && blessed $session;

   $session->realm($self->realm) if $session->can('realm');

   my $user = $args->{user} or return;

   $self->update_session($session, $user->profile_value);

   $session->email($user->email)          if $session->can('email');
   $session->id($user->id)                if $session->can('id');
   $session->role($user->role->role_name) if $session->can('role');
   $session->username($user->user_name)   if $session->can('username');
   return;
}

use namespace::autoclean;

1;

__END__

=pod

=encoding utf-8

=head1 Name

App::MCP::Authentication::Realms::DBIC - Master Control Program - Dependency and time based job scheduler

=head1 Synopsis

   use App::MCP::Authentication::Realms::DBIC;
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
