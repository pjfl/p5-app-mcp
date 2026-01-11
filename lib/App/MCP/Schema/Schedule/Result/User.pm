package App::MCP::Schema::Schedule::Result::User;

use overload '""' => sub { $_[0]->_as_string },
             '+'  => sub { $_[0]->_as_number }, fallback => 1;

use App::MCP::Constants        qw( EXCEPTION_CLASS FALSE NUL TRUE );
use Unexpected::Types          qw( Bool HashRef Int Object );
use App::MCP::Util             qw( base64_encode boolean_data_type
                                   create_totp_token foreign_key_data_type
                                   get_salt new_salt serial_data_type
                                   text_data_type truncate varchar_data_type );
use Crypt::Eksblowfish::Bcrypt qw( bcrypt );
use Scalar::Util               qw( blessed );
use Unexpected::Functions      qw( throw AccountInactive IncorrectAuthCode
                                   IncorrectPassword PasswordDisabled
                                   PasswordExpired UnknownRole Unspecified );
use Auth::GoogleAuth;
use Crypt::SRP;
use DBIx::Class::Moo::ResultClass;

extends 'App::MCP::Schema::Base';

my $class  = __PACKAGE__;
my $result = 'App::MCP::Schema::Schedule::Result';

$class->table('users');

$class->add_columns(
   id        => { %{serial_data_type()}, label => 'User ID', hidden => TRUE },
   user_name => { %{varchar_data_type(64)}, label => 'User Name' },
   email     => text_data_type(),
   role_id   => {
      %{foreign_key_data_type()},
      cell_traits => ['Capitalise'],
      display     => 'role.role_name',
      label       => 'Role',
   },
   active    => { %{boolean_data_type()}, label => 'Still Active', },
   password  => {
      %{text_data_type()},
      display => sub { truncate shift->result->password, 20 },
      hidden  => TRUE,
   },
   password_expired => { %{boolean_data_type()}, label => 'Password Expired' },
);

$class->set_primary_key('id');

$class->add_unique_constraint('users_email_uniq', ['email']);

$class->add_unique_constraint('users_user_name_uniq', ['user_name']);

$class->belongs_to('role' => "${result}::Role", 'role_id');

$class->has_many('preferences' => "${result}::Preference", 'user_id');

$class->might_have('profile' => "${result}::Preference", sub {
   my $args    = shift;
   my $foreign = $args->{foreign_alias};
   my $self    = $args->{self_alias};

   return {
      "${foreign}.user_id" => { -ident => "${self}.id" },
      "${foreign}.name"    => { '=' => 'profile' }
   };
});

has 'api_execution_allowed' =>
   is      => 'lazy',
   isa     => HashRef,
   default => sub {
      return { enable_2fa => TRUE };
   };

has 'default_role_id' =>
   is      => 'lazy',
   isa     => Int,
   default => sub {
      my $self      = shift;
      my $schema    = $self->result_source->schema;
      my $role_name = $schema->config->user->{default_role};
      my $role      = $schema->resultset('Role')->find({ name => $role_name });

      throw UnknownRole, [$role_name] unless $role;

      return $role->id;
   };

has 'profile_value' =>
   is      => 'lazy',
   isa     => HashRef,
   default => sub {
      my $self    = shift;
      my $profile = $self->profile;

      return $profile ? $profile->value : {};
   };

has 'totp_authenticator' =>
   is      => 'lazy',
   isa     => Object,
   default => sub {
      my $self = shift;

      return Auth::GoogleAuth->new({
         issuer => $self->result_source->schema->config->prefix,
         key_id => $self->user_name,
         secret => $self->totp_secret,
      });
   };

# Private functions
sub _is_disabled ($) {
   return $_[0] =~ m{ \* }mx ? TRUE : FALSE;
}

sub _is_encrypted ($) {
   return $_[0] =~ m{ \A \$\d+[a]?\$ }mx ? TRUE : FALSE;
}

# Public methods
sub activate {
   my $self = shift; $self->active(TRUE); return $self->update;
}

sub assert_can_email {
   my $self = shift;

   throw 'User [_1] has no email address', [$self] unless $self->email;
   throw 'User [_1] has an example email address', [$self]
      unless $self->can_email;

   return;
}

sub authenticate {
   my ($self, $password, $code, $for_update) = @_;

   throw AccountInactive, [$self] unless $self->active;

   throw PasswordDisabled, [$self] if _is_disabled $self->password;

   throw PasswordExpired, [$self] if $self->password_expired && !$for_update;

   throw Unspecified, ['Password'] unless $password;

   my $supplied = $self->encrypt_password($password, $self->password);

   throw IncorrectPassword, [$self] unless $self->password eq $supplied;

   return TRUE if !$self->enable_2fa || $for_update;

   throw Unspecified, ['OTP Code'] unless $code;

   throw IncorrectAuthCode, [$self]
      unless $self->totp_authenticator->verify($code);

   return TRUE;
}

sub can_email {
   my $self = shift;

   return FALSE unless $self->email;
   return FALSE if $self->email =~ m{ \@example\.com \z }mx;
   return TRUE;
}

sub deactivate {
   my $self = shift; $self->active(FALSE); return $self->update;
}

sub enable_2fa {
   my ($self, $value) = @_; return $self->_profile('enable_2fa', $value);
}

sub encrypt_password {
   my ($self, $password, $stored) = @_;

   if ($password =~ m{ \A \{ 5054 \} }mx
       or (defined $stored and $stored =~ m{ \A \$ 5054 \$ }mx)) {
      $password =~ s{ \A \{ 5054 \} }{}mx;

      my $username = $self->user_name;
      my $salt     = $stored ? get_salt $stored : new_salt '5054', '00';
      my $srp      = Crypt::SRP->new('RFC5054-2048bit', 'SHA512');
      my $verifier = $srp->compute_verifier($username, $password, $salt);

      return $salt.base64_encode($verifier);
   }

   my $lf   = $self->result_source->schema->config->user->{load_factor};
   my $salt = $stored ? get_salt $stored : new_salt '2a', $lf;

   return bcrypt($password, $salt);
}

sub execute {
   my ($self, $method) = @_;

   return FALSE unless $self->api_execution_allowed->{$method};

   return $self->$method();
}

sub insert {
   my $self    = shift;
   my $columns = { $self->get_inflated_columns };

   $self->_encrypt_password_column($columns);

   $columns->{role_id} //= $self->default_role_id;
   $self->set_inflated_columns($columns);

   $self->validate unless App::MCP->env_var('bulk_insert');

   return $self->next::method;
}

sub is_authorised {
   my ($self, $session, $roles) = @_;

   return FALSE unless $session;

   my $role          = $session->role;
   my $is_authorised = join NUL, grep { $_ eq $role } @{$roles // []};

   return $self->id == $session->id || $is_authorised ? TRUE : FALSE;
}

sub mobile_phone {
   my ($self, $value) = @_; return $self->_profile('mobile_phone', $value);
}

sub postcode {
   my ($self, $value) = @_; return $self->_profile('postcode', $value);
}

sub set_password {
   my ($self, $old, $new) = @_;

   $self->authenticate($old, NUL, TRUE);
   $self->password($new);
   $self->password_expired(FALSE);
   return $self->update;
}

sub timezone {
   my ($self, $value) = @_; return $self->_profile('timezone', $value);
}

sub totp_secret {
   my ($self, $enabled) = @_;

   my $secret = $self->_profile('totp_secret');

   return $secret unless defined $enabled;

   my $current = $secret ? TRUE : FALSE;

   return $self->_profile('totp_secret', create_totp_token)
      if $enabled && !$current;

   return $self->_profile('totp_secret', NUL) if $current && !$enabled;

   return $secret;
}

sub update {
   my ($self, $columns) = @_;

   $self->set_inflated_columns($columns) if $columns;

   $columns = { $self->get_inflated_columns };
   $self->_encrypt_password_column($columns);

   $self->validate unless App::MCP->env_var('bulk_insert');

   return $self->next::method;
}

sub validation_attributes {
   return { # Keys: constraints, fields, and filters (all hashes)
      constraints    => {
         user_name   => { max_length => 64, min_length => 3, } },
      fields         => {
         password    => { validate => 'isMandatory' },
         user_name   => {
            validate => 'isMandatory isValidIdentifier isValidLength' }, },
   };
}

# Private methods
sub _as_number {
   return $_[0]->id;
}

sub _as_string {
   return $_[0]->user_name;
}

sub _encrypt_password_column {
   my ($self, $columns) = @_;

   my $password = $columns->{password} or return;

   return if _is_disabled $password or _is_encrypted $password;

   $columns->{password} = $self->encrypt_password($password);
   $self->set_inflated_columns($columns);
   return;
}

sub _profile {
   my ($self, $key, $value) = @_;

   my $profile = $self->profile_value;

   if (defined $value) {
      $profile->{$key} = $value;

      my $rs = $self->result_source->schema->resultset('Preference');
      my $options = {
         name => 'profile', user_id => $self->id, value => $profile
      };

      $rs->update_or_create($options);
   }

   return $profile->{$key};
}

use namespace::autoclean;

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
