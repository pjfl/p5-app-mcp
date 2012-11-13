# @(#)$Id$

package App::MCP::Schema::Schedule::Result::Job;

use strict;
use warnings;
use feature qw(state);
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );
use parent  qw(App::MCP::Schema::Base);

use Class::Method::Modifiers;
use Class::Usul::Constants;

my $class  = __PACKAGE__;
my $schema = 'App::MCP::Schema::Schedule';

$class->table( 'job' );

$class->load_components( '+App::MCP::MaterialisedPath' );

$class->add_columns
   ( id          => $class->serial_data_type,
     command     => $class->varchar_data_type,
     condition   => $class->nullable_varchar_data_type,
     created     => { data_type     => 'datetime', set_on_create => 1, },
     directory   => $class->nullable_varchar_data_type,
     fqjn        => { data_type     => 'varchar',
                      accessor      => '_fqjn',
                      is_nullable   => FALSE,
                      size          => 255, },
     host        => $class->varchar_data_type( 64, 'localhost' ),
     name        => $class->varchar_data_type( 126 ),
     parent_id   => { data_type     => 'integer',
                      default_value => undef,
                      extra         => { unsigned => TRUE },
                      is_nullable   => TRUE, },
     parent_path => $class->nullable_varchar_data_type,
     type        => { data_type     => 'enum',
                      extra         => { list => $class->job_type_enum },
                      is_enum       => TRUE, },
     user        => $class->varchar_data_type( 32 ), );

$class->set_primary_key( 'id' );

$class->add_unique_constraint( [ 'fqjn' ] );

$class->belongs_to( parent_category  => "${schema}::Result::Job", 'parent_id' );

$class->has_many  ( child_categories => "${schema}::Result::Job", 'parent_id' );

sub fqjn {
   my $self = shift; my $fqjn = $self->_fqjn; $fqjn and return $fqjn;

   return $self->_fqjn( $self->namespace.'::'.$self->name );
}

sub materialised_path_columns {
   return {
      parent => {
         parent_column                => 'parent_id',
         parent_fk_column             => 'id',
         materialised_path_column     => 'parent_path',
         include_self_in_path         => 1,
         include_self_in_reverse_path => 1,
         parent_relationship          => 'parent_category',
         children_relationship        => 'child_categories',
         full_path                    => 'ancestors',
         reverse_full_path            => 'descendants',
         separator                    => __separator(),
      },
   };
}

sub namespace {
   my $self = shift; my $path = $self->parent_path; my $sep = __separator();

   my $id   = (split m{ $sep }msx, $path || NUL)[ 0 ]; state $cache //= {};

   my $ns; $id and $ns = $cache->{ $id }; $ns and return $ns;

   my $name = $self->name;
   my $root = $id   ? $self->result_source->resultset->find( $id ) : FALSE;
      $ns   = $root ? $root->name ne $name ? $root->name : 'main' : 'main';

   return $id ? $cache->{ $id } = $ns : $ns;
}

# Private methods

# Private functions

sub __separator {
   return '/';
}

1;

__END__

=pod

=head1 Name

App::MCP::Schema::Schedule::Result::Job - <One-line description of module's purpose>

=head1 Version

0.1.$Revision$

=head1 Synopsis

   use App::MCP::Schema::Schedule::Result::Job;
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
