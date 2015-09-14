package App::MCP::Model;

use namespace::autoclean;

use App::MCP::Constants   qw( EXCEPTION_CLASS NUL TRUE );
use Class::Usul::Types    qw( LoadableClass Object Plinth );
use HTTP::Status          qw( HTTP_OK );
use Unexpected::Functions qw( ValidationErrors );
use Moo;

with 'Web::Components::Role';
with 'Class::Usul::TraitFor::ConnectInfo';

# Public attributes
has 'application' => is => 'ro', isa => Plinth,
   handles        => [ 'debug' ],
   required       => TRUE,  weak_ref => TRUE;

# Private attributes
has '_schema'       => is => 'lazy', isa => Object, builder => sub {
   my $self = shift; my $extra = $self->config->connect_params;
   $self->schema_class->connect( @{ $self->get_connect_info }, $extra ) },
   reader           => 'schema';

has '_schema_class' => is => 'lazy', isa => LoadableClass,
   builder          => sub { $_[ 0 ]->config->schema_classes->{ 'mcp-model' } },
   reader           => 'schema_class';

sub exception_handler {
   my ($self, $req, $e) = @_;

   my $title = $req->loc( 'Exception Handler' );
   my $page  = { code => $e->rv, error => "${e}", title => $title };

   $e->class eq ValidationErrors->() and $page->{validation_error} = $e->args;

   return $self->get_stash( $req, $page, exception => {} );
}

sub execute {
   my ($self, $method, $req) = @_; return $self->$method( $req );
}

sub get_stash {
   my ($self, $req, $page) = @_; my $stash = $self->initialise_stash( $req );

   $stash->{page} = $self->load_page( $req, $page );

   return $stash;
}

sub initialise_stash {
   return { code => HTTP_OK, view => $_[ 0 ]->config->default_view, };
}

sub load_page {
   my ($self, $req, $page) = @_; $page //= {}; return $page;
}

1;

__END__

=pod

=encoding utf8

=head1 Name

App::MCP::Model - One-line description of the modules purpose

=head1 Synopsis

   use App::MCP::Model;
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
