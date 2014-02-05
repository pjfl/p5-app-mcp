package App::MCP::Schema::Schedule::Result::Job;

use 5.01;
use strict;
use warnings;
use parent 'App::MCP::Schema::Base';

use Algorithm::Cron;
use App::MCP::Constants;
use App::MCP::ExpressionParser;
use App::MCP::Functions    qw( qualify_job_name );
use Class::Usul::Functions qw( is_arrayref is_hashref is_member throw );

my $class = __PACKAGE__; my $result = 'App::MCP::Schema::Schedule::Result';

$class->table( 'job' );

$class->load_components( '+App::MCP::MaterialisedPath' );

$class->add_columns
   ( id          => $class->serial_data_type,
     created     => $class->set_on_create_datetime_data_type,
     command     => $class->varchar_data_type,
     condition   => $class->varchar_data_type,
     crontab     => { accessor      => '_crontab',
                      data_type     => 'varchar',
                      is_nullable   => FALSE,
                      size          => 127, },
     directory   => $class->varchar_data_type,
     expected_rv => $class->numerical_id_data_type( 0 ),
     fqjn        => { accessor      => '_fqjn',
                      data_type     => 'varchar',
                      is_nullable   => FALSE,
                      size          => $class->varchar_max_size, },
     group       => $class->foreign_key_data_type( 1 ),
     host        => $class->varchar_data_type( 64, 'localhost' ),
     name        => $class->varchar_data_type( 126, undef ),
     owner       => $class->foreign_key_data_type( 1 ),
     parent_id   => $class->nullable_foreign_key_data_type,
     parent_path => $class->nullable_varchar_data_type,
     permissions => { accessor      => '_permissions',
                      data_type     => 'smallint',
                      default_value => 488,
                      is_nullable   => FALSE, },
     type        => $class->enumerated_data_type( 'job_type_enum', 'box' ),
     user        => $class->varchar_data_type( 32 ), );

$class->set_primary_key( 'id' );

$class->add_unique_constraint( [ 'fqjn' ] );

$class->belongs_to( parent_category  => "${result}::Job",         'parent_id',
                    { join_type      => 'left' } );

$class->has_many  ( child_categories => "${result}::Job",         'parent_id' );

$class->has_many  ( dependents       => "${result}::JobCondition",   'job_id' );

$class->has_many  ( events           => "${result}::Event",          'job_id' );

$class->has_many  ( processed_events => "${result}::ProcessedEvent", 'job_id' );

$class->might_have( state            => "${result}::JobState",       'job_id' );

$class->belongs_to( owner_rel        => "${result}::User",            'owner' );

$class->belongs_to( group_rel        => "${result}::Role",            'group' );

sub new {
   my ($class, $attr) = @_; my $parent_name = delete $attr->{parent_name};

   my $new = $class->next::method( $attr );

   $parent_name
      and $new->_set_parent_id( $parent_name, { $new->get_inflated_columns } );

   $new->crontab; $new->fqjn; # Force the attributes to take on values

   return $new;
}

sub condition_dependencies {
   return $_[ 0 ]->_eval_condition->[ 1 ];
}

sub crontab {
   my ($self, $crontab) = @_; my @names = CRONTAB_FIELD_NAMES; my $tmp;

   is_hashref  $crontab and $tmp = $crontab
           and $crontab = join SPC, map { $tmp->{ $_ } } @names;
   is_arrayref $crontab and $crontab = join SPC, @{ $crontab };

   my @fields = split m{ \s+ }msx, ($crontab ? $self->_crontab( $crontab )
                                             : $self->_crontab // NUL);

   $self->{ 'crontab_'.$names[ $_ ] } = ($fields[ $_ ] // NUL) for (0 .. 4);

   return $self->_crontab;
}

sub crontab_hour {
   my $self = shift; defined $self->{crontab_hour} or $self->crontab;

   return $self->{crontab_hour};
}

sub crontab_mday {
   my $self = shift; defined $self->{crontab_mday} or $self->crontab;

   return $self->{crontab_mday};
}

sub crontab_min {
   my $self = shift; defined $self->{crontab_min} or $self->crontab;

   return $self->{crontab_min};
}

sub crontab_mon {
   my $self = shift; defined $self->{crontab_mon} or $self->crontab;

   return $self->{crontab_mon};
}

sub crontab_wday {
   my $self = shift; defined $self->{crontab_wday} or $self->crontab;

   return $self->{crontab_wday};
}

sub delete {
   my $self = shift; $self->condition and $self->_delete_condition;

   return $self->next::method;
}

sub eval_condition {
   return $_[ 0 ]->_eval_condition->[ 0 ];
}

sub fqjn { # Fully qualified job name
   my $self = shift; $self->_fqjn and return $self->_fqjn;

   return $self->_fqjn( qualify_job_name( $self->name, $self->namespace ) );
}

sub insert {
   my $self = shift; my $columns = { $self->get_inflated_columns };

   $self->set_inflated_columns( $columns ); $self->_validate;

   my $job = $self->next::method;

   $self->condition and $self->_insert_condition( $job );
   $self->_create_job_state( $job );
   return $job;
}

sub is_executable_by {
   return $_[ 0 ]->_is_permitted( $_[ 1 ], [ 64, 8, 1 ] );
}

sub is_readable_by {
   return $_[ 0 ]->_is_permitted( $_[ 1 ], [ 256, 32, 4 ] );
}

sub is_writable_by {
   return $_[ 0 ]->_is_permitted( $_[ 1 ], [ 128, 16, 2 ] );
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
         separator                    => SEPARATOR,
      },
   };
}

sub namespace {
   my $self = shift;
   my $sep  = SEPARATOR;
   my $path = $self->parent_path;
   my $id   = (split m{ $sep }msx, $path || NUL)[ 0 ];

   state $cache //= {}; $id and $cache->{ $id } and return $cache->{ $id };

   my $root = $id   ? $self->result_source->resultset->find( $id ) : FALSE;
   my $ns   = $root ? $root->id != $id ? $root->name : 'main' : 'main';

   return $root ? $cache->{ $id } = $ns : $ns;
}

sub permissions {
   my ($self, $perms) = @_; $perms and $self->_permissions( oct $perms );

   return sprintf '0%o', $self->_permissions;
}

sub should_start_now {
   my $self      = shift;
   my $crontab   = $self->crontab or return TRUE;
   my $last_time = $self->state ? $self->state->updated->epoch : 0;
   my $cron      = Algorithm::Cron->new( base => 'utc', crontab => $crontab );

   return time >= $cron->next_time( $last_time ) ? TRUE : FALSE;
}

sub sqlt_deploy_hook {
  my ($self, $sqlt_table) = @_;

  $sqlt_table->add_index( name => 'job_idx_fqjn', fields => [ 'fqjn' ] );

  return;
}

sub update {
   my ($self, $columns) = @_; my $condition = $self->condition;

   $columns and $self->set_inflated_columns( $columns ); $self->_validate;

   my $job = $self->next::method;

   $condition ne $self->condition
      and $self->_delete_condition and $job->_insert_condition;

   return $job;
}

sub validation_attributes {
   return { # Keys: constraints, fields, and filters (all hashes)
      fields         => {
         name        => {
            validate => 'isMandatory isSimpleText isValidLength' },
         permissions => { validate => 'isValidInteger' }, },
      constraints    => {
         name        => { max_length => 126, min_length => 1, }, }, };
}

# Private methods
sub _create_job_state {
   my $self = shift; my $schema = $self->result_source->schema;

   return $schema->resultset( 'JobState' )->find_or_create( @_ );
}

sub _delete_condition {
   my $self = shift; my $schema = $self->result_source->schema;

   return $schema->resultset( 'JobCondition' )->delete_dependents( $self );
}

sub _eval_condition {
   my $self = shift; $self->condition or return [ TRUE, [] ];

   my $job_rs = $self->result_source->resultset;

   state $parser //= App::MCP::ExpressionParser->new
      ( external => $job_rs, predicates => $job_rs->predicates );

   return $parser->parse( $self->condition, $self->namespace );
}

sub _insert_condition {
   my $self = shift; my $schema = $self->result_source->schema;

   return $schema->resultset( 'JobCondition' )->create_dependents( $self );
}

sub _is_permitted {
   my ($self, $user_id, $mask) = @_; my $perms = $self->_permissions;

   my $user_rs = $self->result_source->schema->resultset( 'User' );
   my $user    = $user_rs->find( $user_id );

   $perms & $mask->[ 2 ] and return TRUE;
   $perms & $mask->[ 1 ]
      and is_member( $self->group, map { $_->id } $user->roles )
      and return TRUE;
   $perms & $mask->[ 0 ] and $self->owner == $user->id and return TRUE;
   return FALSE;
}

sub _set_parent_id {
   my ($self, $parent_name, $columns) = @_;

   my $job_rs = $self->result_source->resultset;
   my $parent = $job_rs->search( { fqjn => $parent_name } )->single
      or throw error => 'Job [_1] unknown', args => [ $parent_name ];

   $parent->is_writable_by( $columns->{owner} )
      or throw error => 'Job [_1] write permission denied to [_1]',
               args  => [ $parent_name, $columns->{owner} ];
   $columns->{parent_id} = $parent->id;
   $self->set_inflated_columns( $columns );
   return;
}

1;

__END__

=pod

=head1 Name

App::MCP::Schema::Schedule::Result::Job - <One-line description of module's purpose>

=head1 Synopsis

   use App::MCP::Schema::Schedule::Result::Job;
   # Brief but working code examples

=head1 Description

=head1 Configuration and Environment

=head1 Subroutines/Methods

=head2 new

=head2 fqjn

=head2 insert

=head2 materialised_path_columns

=head2 namespace

=head2 update

=head2 validation_attributes

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

Copyright (c) 2014 Peter Flanigan. All rights reserved

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
