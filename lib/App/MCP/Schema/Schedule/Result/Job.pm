# @(#)$Id$

package App::MCP::Schema::Schedule::Result::Job;

use strict;
use warnings;
use feature qw(state);
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );
use parent  qw(App::MCP::Schema::Base);

use CatalystX::Usul::Constants;
use CatalystX::Usul::Functions qw(is_hashref throw);

my $class  = __PACKAGE__;
my $schema = 'App::MCP::Schema::Schedule';

$class->table( 'job' );

$class->load_components( '+App::MCP::MaterialisedPath' );

$class->add_columns
   ( id          => $class->serial_data_type,

     command     => $class->varchar_data_type,

     condition   => $class->varchar_data_type,

     created     => { data_type     => 'datetime', set_on_create => TRUE, },

     directory   => $class->varchar_data_type,

     fqjn        => { data_type     => 'varchar',
                      accessor      => '_fqjn',
                      is_nullable   => FALSE,
                      size          => $class->varchar_max_size, },

     host        => $class->varchar_data_type( 64, 'localhost' ),

     name        => $class->varchar_data_type( 126, undef ),

     parent_id   => { data_type     => 'integer',
                      default_value => undef,
                      extra         => { unsigned => TRUE },
                      is_nullable   => TRUE, },

     parent_path => $class->nullable_varchar_data_type,

     type        => { data_type     => 'enum',
                      default_value => 'box',
                      extra         => { list => $class->job_type_enum },
                      is_enum       => TRUE, },

     user        => $class->varchar_data_type( 32 ), );

$class->set_primary_key( 'id' );

$class->add_unique_constraint( [ 'fqjn' ] );

$class->belongs_to( parent_category  => "${schema}::Result::Job", 'parent_id' );

$class->has_many  ( child_categories => "${schema}::Result::Job", 'parent_id' );

$class->has_many  ( events           => "${schema}::Result::Event",  'job_id' );

$class->has_many  ( archived_events  => "${schema}::Result::EventArchive",
                    'job_id' );

sub new {
   my ($class, $attr) = @_; my $new = $class->next::method( $attr );

   $new->fqjn; # Force the attribute to take on a value

   return $new;
}

sub fqjn { # Fully qualified job name
   my $self = shift; my $fqjn = $self->_fqjn; $fqjn and return $fqjn;

   return $self->_fqjn( $self->namespace.'::'.($self->name || 'void') );
}

sub get_validation_attributes {
   return { # Keys: constraints, fields, and filters (all hashes)
      fields         => {
         name        => {
            validate => 'isMandatory isSimpleText isValidLength' }, },
      constraints    => {
         name        => { max_length => 126, min_length => 1, }, }, };
}

sub insert {
   my $self = shift; $self->_validate; return $self->next::method;
}

sub materialised_path_columns {
   return {
      parent => {
         parent_column                => 'parent_id',
         parent_fk_column             => 'id',
         materialised_path_column     => 'parent_path',
         include_self_in_path         => TRUE,
         include_self_in_reverse_path => TRUE,
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

sub update {
   my ($self, $columns) = @_;

   $self->set_inflated_columns( %{ $columns } ); $self->_validate;

   return $self->next::method;
}

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

=head2 new

=head2 fqjn

=head2 get_validation_attributes

=head2 insert

=head2 materialised_path_columns

=head2 namespace

=head2 update

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
