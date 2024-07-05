package App::MCP::Role::Config;

use Class::Usul::Cmd::Types qw( ConfigProvider );
use Scalar::Util            qw( blessed );
use App::MCP::Config;
use Moo::Role;

has 'config' => is => 'ro', isa => ConfigProvider;

around 'BUILDARGS' => sub {
   my ($orig, $self, @args) = @_;

   my $attr   = $orig->($self, @args);
   my $config = $attr->{config} // { appclass => 'App::MCP' };

   $attr->{config} = App::MCP::Config->new($config) unless blessed $config;

   return $attr;
};

use namespace::autoclean;

1;

__END__

=pod

=encoding utf-8

=head1 Name

App::MCP::Role::Config - Master Control Program - Dependency and time based job scheduler

=head1 Synopsis

   use App::MCP::Role::Config;
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

=item L<Class::Usul::Cmd>

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
