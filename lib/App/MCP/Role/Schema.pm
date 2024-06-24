package App::MCP::Role::Schema;

use Type::Utils qw( class_type );
use App::MCP::JobServer;
use Moo::Role;

has 'jobdaemon' =>
   is      => 'lazy',
   isa     => class_type('App::MCP::JobServer'),
   default => sub {
      my $self = shift;

      return App::MCP::JobServer->new(config => {
         appclass => $self->config->appclass,
         pathname => $self->config->bin->catfile('mcp-jobserver'),
      });
   };

has 'schema' =>
   is      => 'lazy',
   isa     => class_type('DBIx::Class::Schema'),
   default => sub {
      my $self   = shift;
      my $class  = $self->config->schema_class;
      my $schema = $class->connect(@{$self->config->connect_info});

      $class->config($self->config) if $class->can('config');

      $schema->jobdaemon($self->jobdaemon) if $schema->can('jobdaemon');

      return $schema;
   };

use namespace::autoclean;

1;

__END__

=pod

=encoding utf-8

=head1 Name

App::MCP::Role::Schema - Master Control Program - Dependency and time based job scheduler

=head1 Synopsis

   use App::MCP::Role::Schema;
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
