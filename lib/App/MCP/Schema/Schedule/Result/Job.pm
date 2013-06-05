# @(#)$Ident: Job.pm 2013-06-04 23:50 pjf ;

package App::MCP::Schema::Schedule::Result::Job;

use strict;
use warnings;
use feature                 qw(state);
use version; our $VERSION = qv( sprintf '0.2.%d', q$Rev: 19 $ =~ /\d+/gmx );
use parent                  qw(App::MCP::Schema::Base);

use Algorithm::Cron;
use App::MCP::ExpressionParser;
use Class::Usul::Constants;
use Class::Usul::Functions  qw(is_arrayref is_hashref throw);

my $class = __PACKAGE__; my $result = 'App::MCP::Schema::Schedule::Result';

$class->table( 'job' );

$class->load_components( '+App::MCP::MaterialisedPath' );

$class->add_columns
   ( id          => $class->serial_data_type,
     created     => $class->set_on_create_datetime_data_type,
     command     => $class->varchar_data_type,
     condition   => $class->varchar_data_type,
     crontab     => { data_type   => 'varchar',
                      accessor    => '_crontab',
                      is_nullable => FALSE,
                      size        => 127, },
     directory   => $class->varchar_data_type,
     expected_rv => $class->numerical_id_data_type( 0 ),
     fqjn        => { data_type   => 'varchar',
                      accessor    => '_fqjn',
                      is_nullable => FALSE,
                      size        => $class->varchar_max_size, },
     host        => $class->varchar_data_type( 64, 'localhost' ),
     name        => $class->varchar_data_type( 126, undef ),
     parent_id   => $class->nullable_foreign_key_data_type,
     parent_path => $class->nullable_varchar_data_type,
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

sub new {
   my ($class, $attr) = @_; my $new = $class->next::method( $attr );

   $new->crontab; $new->fqjn; # Force the attributes to take on a values

   return $new;
}

sub condition_dependencies {
   return $_[ 0 ]->_eval_condition->[ 1 ];
}

sub crontab {
   my ($self, $crontab) = @_; my @names  = qw(min hour mday mon wday); my $tmp;

   is_hashref  $crontab and $tmp = $crontab
           and $crontab = join SPC, map { $tmp->{ $names[ $_ ] } } 0 .. 4;
   is_arrayref $crontab and $crontab = join SPC, @{ $crontab };

   my @fields = split m{ \s+ }msx, $crontab ? $self->_crontab( $crontab )
                                            : $self->_crontab || NUL;

   $self->{ 'crontab_'.$names[ $_ ] } = $fields[ $_ ] for (0 .. 4);

   return $self->_crontab;
}

sub crontab_hour {
   return $_[ 0 ]->{crontab_hour};
}

sub crontab_mday {
   return $_[ 0 ]->{crontab_mday};
}

sub crontab_min {
   return $_[ 0 ]->{crontab_min};
}

sub crontab_mon {
   return $_[ 0 ]->{crontab_mon};
}

sub crontab_wday {
   return $_[ 0 ]->{crontab_wday};
}

sub delete {
   my $self = shift; $self->condition and $self->_delete_condition;

   return $self->next::method;
}

sub eval_condition {
   return $_[ 0 ]->_eval_condition->[ 0 ];
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
   my $self = shift; $self->_validate; my $job = $self->next::method;

   $self->condition and $self->_insert_condition( $job->id );
   $self->_create_job_state( $job );
   return $job;
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

   my $root = $id   ? $self->result_source->resultset->find( $id ) : FALSE;
      $ns   = $root ? $root->id != $id ? $root->name : 'main' : 'main';

   return $root ? $cache->{ $id } = $ns : $ns;
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
   my ($self, $columns) = @_; my $update_condition = FALSE;

  ($columns->{condition} || NUL) ne $self->condition
     and $update_condition = TRUE;

   $self->set_inflated_columns( %{ $columns } ); $self->_validate;

   my $job = $self->next::method;

   $update_condition and $self->_delete_condition and $job->_insert_condition;

   return $job;
}

# Private methods
sub _delete_condition {
   return $_[ 0 ]->_job_condition_rs->delete_dependents( $_[ 0 ] );
}

sub _eval_condition {
   my $self = shift; $self->condition or return [ TRUE, [] ];

   my $j_rs = $self->result_source->resultset;

   state $parser //= App::MCP::ExpressionParser->new
      ( external => $j_rs, predicates => $j_rs->predicates );

   return $parser->parse( $self->condition, $self->namespace );
}

sub _insert_condition {
   return $_[ 0 ]->_job_condition_rs->create_dependents( $_[ 0 ] );
}

sub _create_job_state {
   return $_[ 0 ]->_job_state_rs->find_or_create( $_[ 1 ] );
}

sub _job_condition_rs {
   state $rs //= $_[ 0 ]->result_source->schema->resultset( 'JobCondition' );

   return $rs;
}

sub _job_state_rs {
   state $rs //= $_[ 0 ]->result_source->schema->resultset( 'JobState' );

   return $rs;
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

This documents version v0.2.$Rev: 19 $

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

=head2 namespace

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

Copyright (c) 2013 Peter Flanigan. All rights reserved

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
