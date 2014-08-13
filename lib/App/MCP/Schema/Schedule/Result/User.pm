package App::MCP::Schema::Schedule::Result::User;

use strictures;
use overload '""' => sub { $_[ 0 ]->as_string }, fallback => 1;
use parent   'App::MCP::Schema::Base';

use App::MCP::Constants        qw( TRUE FALSE NUL );
use App::MCP::Functions        qw( get_salt );
use Class::Usul::Functions     qw( base64_encode_ns create_token throw );
use Crypt::Eksblowfish::Bcrypt qw( bcrypt en_base64 );
use Crypt::SRP;
use HTTP::Status               qw( HTTP_UNAUTHORIZED );
use Try::Tiny;
use Unexpected::Functions      qw( AccountInactive IncorrectPassword );

my $class = __PACKAGE__; my $result = 'App::MCP::Schema::Schedule::Result';

$class->table( 'user' );

$class->add_columns
   ( id            => $class->serial_data_type,
     username      => $class->varchar_data_type( 64, NUL ),
     active        => { data_type     => 'boolean',
                        default_value => FALSE,
                        is_nullable   => FALSE, },
     role_id       => $class->foreign_key_data_type,
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
                        is_nullable   => TRUE, },
     password      => $class->varchar_data_type( 384, NUL ),
     email_address => $class->varchar_data_type( 64, NUL ),
     first_name    => $class->varchar_data_type( 64, NUL ),
     last_name     => $class->varchar_data_type( 64, NUL ),
     home_phone    => $class->varchar_data_type( 64, NUL ),
     location      => $class->varchar_data_type( 64, NUL ),
     project       => $class->varchar_data_type( 64, NUL ),
     work_phone    => $class->varchar_data_type( 64, NUL ), );

$class->set_primary_key( 'id' );

$class->add_unique_constraint( [ 'username' ] );

$class->belongs_to  ( primary_role => "${result}::Role",     'role_id' );

$class->has_many    ( user_role    => "${result}::UserRole", 'user_id' );

$class->many_to_many( roles        => 'user_role',              'role' );

sub activate {
   my $self = shift; $self->active( TRUE ); return $self->update;
}

sub add_member_to {
   my ($self, $role) = @_; my $failed = FALSE;

   try { $self->assert_member_of( $role ) } catch { $failed = TRUE };

   $failed or throw error => 'User [_1] already a member of role [_2]',
                    args  => [ $self->username, $role->rolename ];

   return $self->user_role->create( { user_id => $self->id,
                                      role_id => $role->id } );
}

sub as_string {
   return $_[ 0 ]->username;
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

   $self->active or throw class => AccountInactive,
                          args  => [ $self->username ], rv => HTTP_UNAUTHORIZED;

   my $username = $self->username;
   my $stored   = $self->password || NUL;
   my $supplied = $self->_encrypt_password( $username, $password, $stored );

   $supplied eq $stored
      or throw class => IncorrectPassword,
               args  => [ $self->username ], rv => HTTP_UNAUTHORIZED;

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
   my $username = $columns->{username};

   $password and not __is_encrypted( $password ) and $columns->{password}
      = $self->_encrypt_password( $username, $password );
   $columns->{role_id} ||= $self->_default_role_id;
   $self->set_inflated_columns( $columns );

   return $self->next::method;
}

sub list_other_roles {
   my $self = shift;

   return [ map { NUL.$_->role }
            $self->user_role->search( { user_id => $self->id } )->all ];
}

sub validation_attributes {
   return { # Keys: constraints, fields, and filters (all hashes)
      constraints    => {
         username    => { max_length => 64, min_length => 1, } },
      fields         => {
         password    => { validate => 'isMandatory' },
         username    => {
            validate => 'isMandatory isValidIdentifier isValidLength' }, },
   };
}

# Private methods
sub _default_role_id {
   my $self = shift; return 1; # TODO: Derive default role_id from self
}

sub _encrypt_password {
   my ($self, $username, $password, $stored) = @_;

   my $salt     = defined $stored ? get_salt( $stored )
                : __new_salt( $self->result_source->resultset->load_factor );
   my $crypted  = __get_hashed_pw( bcrypt( $password, $salt ) );
   my $srp      = Crypt::SRP->new( 'RFC5054-2048bit', 'SHA512' );
   my $verifier = $srp->compute_verifier( $username, $crypted, $salt );

   return $salt.base64_encode_ns( $verifier );
}

# Private functions
sub __get_hashed_pw {
   my $crypted = shift; my @parts = split m{ [\$] }mx, $crypted;

   return substr $parts[ -1 ], 22;
}

sub __new_salt {
   my $lf = shift;

   return "\$2a\$${lf}\$"
      .(en_base64( pack( 'H*', substr( create_token, 0, 32 ) ) ) );
}

sub __is_encrypted {
   return $_[ 0 ] =~ m{ \A \$\d+[a]?\$ }mx ? TRUE : FALSE;
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
