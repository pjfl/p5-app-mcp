package App::MCP::Controller::API;

use Web::Components::Util qw( build_routes );
use Web::Simple;

with 'Web::Components::Role';
with 'Web::Components::ReverseMap';

has '+moniker' => default => 'api';

sub dispatch_request { build_routes
   'GET      + /api/footer/** + ?*'               => 'api/footer',
   'GET      + /api/form/*/field/*/validate + ?*' => 'api/form/field/validate',
   'POST     + /api/level/*/log + ?*'             => 'api/loglevel/logger',
   'GET      + /api/messages/collect + ?*'        => 'api/collect_messages',
   'GET      + /api/object/*/fetch + ?*'          => 'api/object/fetch',
   'GET      + /api/push/publickey + ?*'          => 'api/push_publickey',
   'POST     + /api/push/register + ?*'           => 'api/push_register',
   'GET      + /service-worker'                   => 'api/push_worker',
   'POST     + /api/table/*/action + ?*'          => 'api/table/action',
   'GET|POST + /api/table/*/preference + ?*'      => 'api/table/preference',
   'GET|POST + /api/tabs/preference + ?*'         => 'api/tabs_preference',

   'GET|POST + /api/diagram/*/preference + ?*' => 'api/diagram/diag_preference',

   'GET  + /worker/user/*/exchange_keys + ?*' => 'worker/user/exchange_keys',
   'POST + /worker/user/*/authenticate  + ?*' => 'worker/user/authenticate',
   'POST + /worker/session/*/create_job + ?*' => 'worker/sessionid/create_job',
   'POST + /worker/run/*/create_event   + ?*' => 'worker/runid/create_event',
}

1;

__END__

=pod

=encoding utf-8

=head1 Name

App::MCP::Controller::API - Master Control Program - Dependency and time based job scheduler


=head1 Synopsis

   use App::MCP::Controller::API;
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
