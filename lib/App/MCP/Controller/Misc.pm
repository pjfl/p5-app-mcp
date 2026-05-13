package App::MCP::Controller::Misc;

use Web::Components::Util qw( build_routes );
use Web::Simple;

with 'Web::Components::Role';
with 'Web::Components::ReverseMap';

has '+moniker' => default => 'misc';

sub dispatch_request { build_routes
   'GET|POST + /user/create + ?*'       => 'user/root/base/create',
   'POST     + /user/*/delete + ?*'     => 'user/root/user/delete',
   'GET|POST + /user/*/edit + ?*'       => 'user/root/user/edit',
   'GET      + /user/*/password/* + ?*' => 'misc/root/user/password_update',
   'GET|POST + /user/*/password + ?*'   => 'misc/root/user/password',
   'GET|POST + /user/*/profile + ?*'    => 'user/root/user/profile',
   'POST     + /user/*/remove + ?*'     => 'user/root/user/remove',
   'GET|POST + /user/*/totp/reset + ?*' => 'misc/root/user/totp_reset',
   'GET      + /user/*/totp/* + ?*'     => 'misc/root/user/totp',
   'GET      + /user/*/totp + ?*'       => 'user/root/user/totp',
   'GET      + /user/* + ?*'            => 'user/root/user/view',
   'GET      + /user + ?*'              => 'user/root/base/list',

   'GET|POST + /role/create + ?*'   => 'role/root/base/create',
   'POST     + /role/*/delete + ?*' => 'role/root/role/delete',
   'GET|POST + /role/*/edit + ?*'   => 'role/root/role/edit',
   'POST     + /role/*/remove + ?*' => 'role/root/role/remove',
   'GET      + /role/* + ?*'        => 'role/root/role/view',
   'GET      + /role + ?*'          => 'role/root/base/list',

   'GET      + /doc/configuration + ?*' => 'doc/root/base/configuration',
   'GET      + /doc/server + ?*'        => 'doc/root/base/server',
   'GET      + /doc + ?*'               => 'doc/root/base/application',

   'GET      + /logfile/*.* + ?*' => 'logfile/root/base/view',
   'GET      + /logfile + ?*'     => 'logfile/root/base/list',

   'GET      + /changes + ?*'      => 'misc/root/base/changes',
   'POST     + /login + ?*'        => 'misc/root/base/login_dispatch',
   'GET      + /login + ?*'        => 'misc/root/base/login',
   'POST     + /logout + ?*'       => 'misc/root/logout',
   'GET      + /oauth/* + ?*'      => 'misc/root/base/oauth',
   'GET      + /register/* + ?*'   => 'misc/root/base/create_user',
   'GET|POST + /register + ?*'     => 'misc/root/base/register',
   'GET      + /unauthorised + ?*' => 'misc/root/base/unauthorised',
}

1;

__END__

=pod

=encoding utf-8

=head1 Name

App::MCP::Controller::Misc - Master Control Program - Dependency and time based job scheduler


=head1 Synopsis

   use App::MCP::Controller::Misc;
   # Brief but working code examples

=head1 Description

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=cut

=back

=head1 Subroutines/Methods

Defineds the following methods;

=over 3

=cut

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
http://rt.cpan.org/NoAuth/Bugs.html?Dist=App-MCP.
Patches are welcome

=head1 Acknowledgements

Larry Wall - For the Perl programming language

=head1 Author

Peter Flanigan, C<< <pjfl@cpan.org> >>

=head1 License and Copyright

Copyright (c) 2026 Peter Flanigan. All rights reserved

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
