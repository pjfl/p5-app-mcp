# @(#)$Id$

package App::MCP::Schema::Schedule::Result::Job;

use strict;
use warnings;
use feature qw(state);
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );
use parent  qw(App::MCP::Schema::Base);

use CatalystX::Usul::Constants;
use CatalystX::Usul::Functions qw(throw);

my $class = __PACKAGE__; my $schema = 'App::MCP::Schema::Schedule';

$class->table( 'job' );

$class->load_components( '+App::MCP::MaterialisedPath' );

$class->add_columns
   ( id          => $class->serial_data_type,
     created     => $class->set_on_create_datetime_data_type,
     command     => $class->varchar_data_type,
     condition   => $class->varchar_data_type,
     directory   => $class->varchar_data_type,
     expected_rv => $class->numerical_id_data_type( 0 ),
     fqjn        => { data_type     => 'varchar',
                      accessor      => '_fqjn',
                      is_nullable   => FALSE,
                      size          => $class->varchar_max_size, },
     host        => $class->varchar_data_type( 64, 'localhost' ),
     name        => $class->varchar_data_type( 126, undef ),
     parent_id   => $class->nullable_foreign_key_data_type,
     parent_path => $class->nullable_varchar_data_type,
     type        => $class->enumerated_data_type( 'job_type_enum', 'box' ),
     user        => $class->varchar_data_type( 32 ), );

$class->set_primary_key( 'id' );

$class->add_unique_constraint( [ 'fqjn' ] );

$class->belongs_to( parent_category  => "${schema}::Result::Job", 'parent_id' );

$class->has_many  ( child_categories => "${schema}::Result::Job", 'parent_id' );

$class->has_many  ( events           => "${schema}::Result::Event",  'job_id' );

$class->might_have( state            => "${schema}::Result::JobState",   'id' );

$class->has_many  ( processed_events => "${schema}::Result::ProcessedEvent",
                    'job_id' );

$class->has_many  ( dependents       => "${schema}::Result::JobCondition",
                    'id' );

sub new {
   my ($class, $attr) = @_; my $new = $class->next::method( $attr );

   $new->fqjn; # Force the attribute to take on a value

   return $new;
}

sub delete {
   my $self = shift; $self->condition and $self->_delete_condition( $self->id );

   return $self->next::method;
}

sub fqjn { # Fully qualified job name
   my $self = shift; my $fqjn = $self->_fqjn; $fqjn and return $fqjn;

   return $self->_fqjn( $self->_namespace.'::'.($self->name || 'void') );
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
   my $self = shift; $self->_validate; my $r = $self->next::method;

   $self->condition and $self->_insert_condition( $r->id );

   return $r;
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

sub sqlt_deploy_hook {
  my ($self, $sqlt_table) = @_;

  $sqlt_table->add_index( name => 'job_fqjn_index', fields => [ 'fqjn' ] );

  return;
}

sub update {
   my ($self, $columns) = @_; my $condition = $self->condition;

   $self->set_inflated_columns( %{ $columns } ); $self->_validate;

   my $r = $self->next::method;

   ($condition or $r->condition)
      and $self->_update_condition( $r->id, $condition );

   return $r;
}

# Private methods

sub _delete_condition {
   $_[ 0 ]->_job_condition_rs->delete_dependents( $_[ 1 ] ); return;
}

sub _insert_condition {
   my ($self, $id) = @_; my $rs = $self->_job_condition_rs;

   $rs->create_dependents( $id, $self->condition, $self->_namespace );

   return;
}

sub _job_condition_rs {
   state $rs //= $_[ 0 ]->result_source->schema->resultset( 'JobCondition' );

   return $rs;
}

sub _namespace {
   my $self = shift; my $path = $self->parent_path; my $sep = __separator();

   my $id   = (split m{ $sep }msx, $path || NUL)[ 0 ]; state $cache //= {};

   my $ns; $id and $ns = $cache->{ $id }; $ns and return $ns;

   my $root = $id   ? $self->result_source->resultset->find( $id ) : FALSE;
      $ns   = $root ? $root->id != $id ? $root->name : 'main' : 'main';

   return $root ? $cache->{ $id } = $ns : $ns;
}

sub _update_condition {
   my ($self, $id, $old_condition) = @_; $old_condition ||= '';

   my $new_condition = $self->condition || '';

   $old_condition eq $new_condition and return;
   $self->_delete_condition( $id );
   $self->_insert_condition( $id );
   return;
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

=head2 update

=head2 _namespace

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
