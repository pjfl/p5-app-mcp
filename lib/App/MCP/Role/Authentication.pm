package App::MCP::Role::Authentication;

use App::MCP::Constants    qw( EXCEPTION_CLASS FALSE TRUE );
use Unexpected::Types      qw( HashRef Object Str );
use Class::Usul::Cmd::Util qw( ensure_class_loaded );
use Unexpected::Functions  qw( throw Unspecified );
use Moo::Role;

requires qw( schema session );

has '_auth_namespace' =>
   is      => 'ro',
   isa     => Str,
   default => 'App::MCP::Authentication::Realms';

has '_auth_realms' => is => 'ro', isa => HashRef[Object], default => sub { {} };

sub authenticate {
   my ($self, $args, $realm) = @_;

   $args //= {};
   $args->{user} //= $self->find_user($args, $realm);

   return $self->_find_realm($realm)->authenticate($args);
}

sub find_user {
   my ($self, $args, $realm) = @_;

   $args //= {};
   $args->{session} = $self->session;

   return $self->_find_realm($realm)->find_user($args);
}

sub logout {
   my $self = shift;

   $self->session->authenticated(FALSE);
   return;
}

sub set_authenticated {
   my ($self, $args, $realm) = @_;

   $args //= {};
   $args->{user} //= $self->find_user($args, $realm);
   $args->{session} = $self->session;
   $self->session->authenticated(TRUE);

   return $self->_find_realm($realm)->to_session($args);
}

# Private methods
sub _find_realm {
   my ($self, $realm) = @_;

   my $config = { %{$self->config->authentication} };

   $realm //= $config->{default_realm};

   throw Unspecified, ['default_realm'] unless $realm;

   return $self->_auth_realms->{$realm} if exists $self->_auth_realms->{$realm};

   my $ns    = $config->{namespace} // $self->_auth_namespace;
   my $class = $config->{classes}->{$realm} // ucfirst $realm;

   $class = ('+' eq substr $realm, 0, 1) ? substr $realm, 1 : "${ns}::${class}";

   ensure_class_loaded $class;

   my $attr = {
      %{$config->{$realm} // {}}, realm => $realm, schema => $self->schema
   };

   return $self->_auth_realms->{$realm} = $class->new($attr);
}

use namespace::autoclean;

1;

__END__

=pod

=encoding utf-8

=head1 Name

App::MCP::Role::Authentication - Master Control Program - Dependency and time based job scheduler

=head1 Synopsis

   use App::MCP::Role::Authentication;
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

Copyright (c) 2024 Peter Flanigan. All rights reserved

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
