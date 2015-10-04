package App::MCP::Model::State;

use App::MCP::Attributes;
use Moo;

extends 'App::MCP::Model';
with    'App::MCP::Role::PageConfiguration';
with    'App::MCP::Role::FormBuilder';
with    'App::MCP::Role::WebAuthentication';

has '+moniker' => default => 'state';

sub diagram : Role(any) {
   my ($self, $req) = @_; my $page = { title => 'State Diagram' };

   return $self->get_stash( $req, $page, diagram => {} );
}

sub _diagram_state_assign_hook {
   my ($self, $req, $field, $row, $value) = @_;

   my $data = {
      'Root Folder'           => {
         'Label One'          => {
            _tip              => q(Help text for label one),
            'Label Three'     => {
               _tip           => q(Help text for label three),
               'Label Four'   => {
                  _tip        => q(Help text for label four),
                  'Label Six' => {
                     _tip     => q(Help text for label six) }, },
               'Label Five'   => {
                  _tip        => q(Help text for label five) },
               'Label Seven'  => {
                  _tip        => q(Help text for label seven) }, },
            'Label Eight'     => {
               _tip           => q(Help text for label eight) }, },
         'Label Two'          => {
            _tip              => q(Help text for label two) },
      } };

   return { data => $data };
}

1;

__END__

=pod

=encoding utf8

=head1 Name

App::MCP::Model::State - One-line description of the modules purpose

=head1 Synopsis

   use App::MCP::Model::State;
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

Copyright (c) 2015 Peter Flanigan. All rights reserved

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
