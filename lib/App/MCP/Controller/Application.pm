package App::MCP::Controller::Application;

use Web::Components::Util qw( build_routes );
use Web::Simple;

with 'Web::Components::Role';
with 'Web::Components::ReverseMap';

has '+moniker' => default => 'application';

sub dispatch_request { build_routes
   'GET|POST + /job/create + ?*'   => 'job/root/base/create',
   'GET      + /job/history + ?*'  => 'history/root/base/list',
   'GET|POST + /job/select + ?*'   => 'job/root/base/select',
   'POST     + /job/*/delete + ?*' => 'job/root/jobid/delete',
   'GET|POST + /job/*/edit + ?*'   => 'job/root/jobid/edit',
   'GET      + /job/*/events + ?*' => 'history/root/jobid/view',
   'GET      + /job/*/run/* + ?*'  => 'history/root/jobid/runid/runview',
   'GET      + /job/*/run + ?*'    => 'history/root/jobid/runlist',
   'GET      + /job/* + ?*'        => 'job/root/jobid/view',
   'GET      + /job + ?*'          => 'job/root/base/list',

   'GET|POST + /state/*/edit + ?*' => 'state/root/base/jobid/edit',
   'GET      + /state        + ?*' => 'state/root/base/view',
}

1;

__END__

=pod

=encoding utf-8

=head1 Name

App::MCP::Controller::Application - Master Control Program - Dependency and time based job scheduler


=head1 Synopsis

   use App::MCP::Controller::Application;
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
