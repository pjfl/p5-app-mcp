# @(#)$Id$

package App::MCP::Workflow::JSON;

use strict;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use Class::Usul::Moose;
use Class::Usul::Constants;
use Class::Usul::Functions       qw(is_hashref throw);
use Class::Workflow;
use English                      qw(-no_match_vars);
use File::DataClass::Constraints qw(Path);
use File::DataClass::Schema;
use JSON                         qw();

has code_key     => is => 'ro', isa => NonEmptySimpleStr,
   default       => 'code';

has path         => is => 'ro', isa => Path, coerce => TRUE;

has workflow_key => is => 'ro', isa => NonEmptySimpleStr,
   default       => 'workflow';

sub load_file {
   my ($self, $path) = @_; my $res = $self->_load_file( $path || $self->path );

   return $self->_inflate_hash( $self->_empty_workflow, $res );
}

sub load_string {
   my ($self, $json) = @_; my $res = $self->_load_string( $json );

   return $self->_inflate_hash( $self->_empty_workflow, $res );
}

# Private methods

sub _empty_workflow {
   return Class::Workflow->new;
}

sub _inflate_hash {
   my ($self, $workflow, $wrapper) = @_;

   my $hash = $wrapper->{ $self->code_key };

   for my $key (keys %{ $hash }) {
      $hash->{ $key } = eval 'sub '.$hash->{ $key }; ## no critic
      $EVAL_ERROR and $hash->{ $key } = undef;
   }

   $hash = $wrapper->{ $self->workflow_key };

   for my $key (keys %{ $hash }) {
      if (my ($type) = ($key =~ m{ \A (state|transition)s \z }msx)) {
         for my $item (@{ $hash->{ $key } }) {
            $workflow->$type( ref $item ? (is_hashref $item
                                           ? %{ $item } : @{ $item }) : $item );
         }
      }
      else { $workflow->$key( $hash->{ $key } ) }
   }

   return $workflow;
}

sub _load_file {
   my ($self, $path) = @_;

   my $attr = { cache_class => q(none), storage_class => q(JSON) };

   return File::DataClass::Schema->new( $attr )->load( $path );
}

sub _load_string {
   my ($self, $data) = @_; $data or return {};

   # The filter causes the data to be untainted (running suid). I shit you not
   my $json = JSON->new->canonical->filter_json_object( sub { $_[ 0 ] } );

   return $json->decode( $data );
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=head1 Name

App::MCP::Workflow::JSON - <One-line description of module's purpose>

=head1 Version

0.1.$Revision$

=head1 Synopsis

   use App::MCP::Workflow::JSON;
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

Copyright (c) 2012 Peter Flanigan. All rights reserved

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
