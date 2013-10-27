# @(#)$Ident: User.pm 2013-10-23 00:14 pjf ;

package App::MCP::Schema::Schedule::Result::User;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.3.%d', q$Rev: 3 $ =~ /\d+/gmx );
use parent                  qw( App::MCP::Schema::Base );

use Class::Usul::Constants;
use Class::Usul::Functions     qw( create_token throw );
use Crypt::Eksblowfish::Bcrypt qw( bcrypt en_base64 );

EXCEPTION_CLASS->has_exception( 'AccountInactive' );
EXCEPTION_CLASS->has_exception( 'IncorrectPassword' );

my $class = __PACKAGE__; my $result = 'App::MCP::Schema::Schedule::Result';

$class->table( 'user' );

$class->add_columns
   ( id            => $class->serial_data_type,
     active        => { data_type     => 'boolean',
                        default_value => FALSE,
                        is_nullable   => FALSE, },
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

   $self->user_role->find( $self->id, $role->id )
      and throw error => 'User [_1] already a member of role [_2]',
                args  => [ $self->username, $role->rolename ];

   return $self->user_role->create( { user_id => $self->id,
                                      role_id => $role->id } );
}

sub assert_member_of {
   my ($self, $role) = @_;

   my $user_role = $self->user_role->find( $self->id, $role->id )
      or throw error => 'User [_1] not member of role [_2]',
               args  => [ $self->username, $role->rolename ];

   return $user_role;
}

sub authenticate {
   my ($self, $password) = @_;

   $self->active
      or throw error => 'User [_1] authentication failed',
               args  => [ $self->username ], class => 'AccountInactive';

   my $stored   = $self->password || NUL;
   my $supplied = $self->_encrypt_password( $password, $stored );

   $supplied eq $stored
      or throw error => 'User [_1] authentication failed',
               args  => [ $self->username ], class => 'IncorrectPassword';

   return;
}

sub deactivate {
   my $self = shift; $self->active( FALSE ); return $self->update;
}

sub delete_member_from {
   return $_[ 0 ]->assert_member_of( $_[ 1 ] )->delete;
}

sub insert {
   my $self = shift; my $columns = { $self->get_inflated_columns };

   $columns->{password} and
      $columns->{password} = $self->_encrypt_password( $columns->{password} );

   $self->set_inflated_columns( $columns );

   return $self->next::method;
}

# Private methods
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

1;

__END__

=pod

=head1 Name

App::MCP::Schema::Schedule::Result::User - <One-line description of module's purpose>

=head1 Version

This documents version v0.3.$Rev: 3 $

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
