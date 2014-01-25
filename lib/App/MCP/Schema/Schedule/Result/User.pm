package App::MCP::Schema::Schedule::Result::User;

use strict;
use warnings;
use parent 'App::MCP::Schema::Base';

use App::MCP::Constants;
use Class::Usul::Functions     qw( create_token throw );
use Crypt::Eksblowfish::Bcrypt qw( bcrypt en_base64 );
use TryCatch;
use Unexpected::Functions      qw( AccountInactive IncorrectPassword );

my $class = __PACKAGE__; my $result = 'App::MCP::Schema::Schedule::Result';

$class->table( 'user' );

$class->add_columns
   ( id            => $class->serial_data_type,
     active        => { data_type     => 'boolean',
                        default_value => FALSE,
                        is_nullable   => FALSE, },
     role_id       => $class->foreign_key_data_type,
     username      => $class->varchar_data_type( 64, NUL ),
     password      => $class->varchar_data_type( 64, NUL ),
     email_address => $class->varchar_data_type( 64, NUL ),
     first_name    => $class->varchar_data_type( 64, NUL ),
     last_name     => $class->varchar_data_type( 64, NUL ),
     home_phone    => $class->varchar_data_type( 64, NUL ),
     location      => $class->varchar_data_type( 64, NUL ),
     project       => $class->varchar_data_type( 64, NUL ),
     work_phone    => $class->varchar_data_type( 64, NUL ),
     pwlast        => { data_type     => 'mediumint',
                        default_value => 0,
                        is_nullable   => FALSE, },
     pwnext        => { data_type     => 'mediumint',
                        default_value => 0,
                        is_nullable   => FALSE, },
     pwafter       => { data_type     => 'mediumint',
                        default_value => 99999,
                        is_nullable   => FALSE, },
     pwwarn        => { data_type     => 'mediumint',
                        default_value => 7,
                        is_nullable   => FALSE, },
     pwexpires     => { data_type     => 'mediumint',
                        default_value => 90,
                        is_nullable   => FALSE, },
     pwdisable     => { data_type     => 'mediumint',
                        default_value => undef,
                        is_nullable   => TRUE, }, );

$class->set_primary_key( 'id' );

$class->add_unique_constraint( [ 'username' ] );

$class->has_many    ( user_role => "${result}::UserRole", 'user_id' );

$class->many_to_many( roles     => 'user_role',              'role' );

sub activate {
   my $self = shift; $self->active( TRUE ); return $self->update;
}

sub add_member_to {
   my ($self, $role) = @_;

   try        { $self->assert_member_of( $role ) }
   catch ($e) {
      return $self->user_role->create( { user_id => $self->id,
                                         role_id => $role->id } );
   }

   throw error => 'User [_1] already a member of role [_2]',
         args  => [ $self->username, $role->rolename ];
}

sub assert_member_of {
   my ($self, $role) = @_;

   $self->role_id == $role->id and return TRUE;

   my $user_role = $self->user_role->find( $self->id, $role->id )
      or throw error => 'User [_1] not member of role [_2]',
               args  => [ $self->username, $role->rolename ];

   return TRUE;
}

sub authenticate {
   my ($self, $password) = @_;

   $self->active or throw class => AccountInactive, args => [ $self->username ];

   my $stored   = $self->password || NUL;
   my $supplied = $self->_encrypt_password( $password, $stored );

   $supplied eq $stored
      or throw class => IncorrectPassword, args => [ $self->username ];

   return;
}

sub deactivate {
   my $self = shift; $self->active( FALSE ); return $self->update;
}

sub delete_member_from {
   my ($self, $role) = @_;

   $self->role_id == $role->id and throw 'Cannot delete from primary role';

   my $user_role = $self->user_role->find( $self->id, $role->id )
      or throw error => 'User [_1] not member of role [_2]',
               args  => [ $self->username, $role->rolename ];

   return $user_role->delete;
}

sub insert {
   my $self     = shift;
   my $columns  = { $self->get_inflated_columns };
   my $password = $columns->{password};

   $password and not __is_encrypted( $password )
      and $columns->{password} = $self->_encrypt_password( $password );
   $columns->{role_id} ||= $self->_default_role_id;
   $self->set_inflated_columns( $columns );

   return $self->next::method;
}

# Private methods
sub _default_role_id {
   my $self = shift; return 1; # TODO: Derive default role_id from self
}

sub _encrypt_password {
   my ($self, $password, $salt) = @_;

   $salt ||= __get_salt( $self->result_source->resultset->load_factor );

   return bcrypt( $password, $salt );
}

# Private functions
sub __get_salt {
   my $lf = shift;

   return "\$2a\$${lf}\$"
      .(en_base64( pack( 'H*', substr( create_token, 0, 32 ) ) ) );
}

sub __is_encrypted {
   return $_[ 0 ] =~ m{ \A \$2a }mx ? TRUE : FALSE;
}

1;

__END__

=pod

=head1 Name

App::MCP::Schema::Schedule::Result::User - <One-line description of module's purpose>

=head1 Synopsis

   use App::MCP::Schema::Schedule::Result::User;
   # Brief but working code examples

=head1 Description

=head1 Configuration and Environment

=head1 Subroutines/Methods

=head1 Diagnostics

=head1 Dependencies

=over 3

=item L<Class::Usul>

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

Peter Flanigan, C<< <Support at RoxSoft dot co dot uk> >>

=head1 License and Copyright

Copyright (c) 2013 Peter Flanigan. All rights reserved

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
