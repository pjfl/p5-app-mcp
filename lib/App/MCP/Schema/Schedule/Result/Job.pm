package App::MCP::Schema::Schedule::Result::Job;

use utf8; # -*- coding: utf-8; -*-
use parent 'App::MCP::Schema::Base';

use App::MCP::Constants    qw( EXCEPTION_CLASS CRONTAB_FIELD_NAMES FALSE
                               JOB_TYPE_ENUM NUL SEPARATOR SPC TRUE
                               VARCHAR_MAX_SIZE );
use App::MCP::Util         qw( boolean_data_type enumerated_data_type
                               foreign_key_data_type
                               nullable_foreign_key_data_type
                               nullable_varchar_data_type
                               numerical_id_data_type serial_data_type
                               set_on_create_datetime_data_type
                               truncate varchar_data_type );
use Class::Usul::Cmd::Util qw( is_member );
use Ref::Util              qw( is_arrayref );
use Unexpected::Functions  qw( throw UnknownJob );
use Algorithm::Cron;
use App::MCP::ExpressionParser;
use DBIx::Class::Moo::ResultClass;

my $class  = __PACKAGE__;
my $result = 'App::MCP::Schema::Schedule::Result';

$class->table('jobs');

$class->load_components('+App::MCP::MaterialisedPath');

$class->add_columns(
   id           => serial_data_type,
   job_name     => { %{varchar_data_type()}, label => 'Job Name' },
   created      => {
      %{set_on_create_datetime_data_type()},
      cell_traits => ['DateTime'],
   },
   type         => enumerated_data_type(JOB_TYPE_ENUM, 'box'),
   owner_id     => foreign_key_data_type(1, 'owner'),
   group_id     => foreign_key_data_type(1, 'group'),
   permissions  => {
      accessor      => '_permissions',
      data_type     => 'smallint',
      default_value => 488,
      is_nullable   => FALSE,
   },
   expected_rv  => numerical_id_data_type(0),
   delete_after => boolean_data_type,
   parent_id    => nullable_foreign_key_data_type,
   parent_path  => nullable_varchar_data_type,
   host         => varchar_data_type(64, 'localhost'),
   user_name    => { %{varchar_data_type(32, 'mcp')}, label => 'User Name' },
   command      => varchar_data_type,
   crontab      => nullable_varchar_data_type(127),
   condition    => {
      %{nullable_varchar_data_type()},
      accessor  => '_condition',
   },
   directory    => nullable_varchar_data_type,
   dependencies => nullable_varchar_data_type,
);

$class->set_primary_key('id');

$class->add_unique_constraint('jobs_job_name_uniq', ['job_name']);

$class->belongs_to( parent_box       => "${result}::Job",         'parent_id',
                    { join_type      => 'left' } );
$class->has_many  ( child_jobs       => "${result}::Job",         'parent_id' );
$class->has_many  ( dependents       => "${result}::JobCondition",   'job_id' );
$class->has_many  ( events           => "${result}::Event",          'job_id' );
$class->has_many  ( processed_events => "${result}::ProcessedEvent", 'job_id' );
$class->might_have( state            => "${result}::JobState",       'job_id' );
$class->belongs_to( owner_rel        => "${result}::User",         'owner_id' );
$class->belongs_to( group_rel        => "${result}::Role",         'group_id' );

has '_condition_changed' => is => 'rw', default => FALSE;

has '_parser' =>
   is      => 'lazy',
   default => sub {
      my $self   = shift;
      my $job_rs = $self->result_source->resultset;

      return App::MCP::ExpressionParser->new(
         external => $job_rs, predicates => $job_rs->predicates
      );
   };

# Public method
sub condition {
   my ($self, $value) = @_;

   return $self->_condition unless defined $value;

   $self->_condition_changed(TRUE) if $self->_condition ne $value;

   return $self->_condition($value);
}

sub crontab_hour {
   my ($self, $value) = @_; return $self->_crontab('hour', $value);
}

sub crontab_mday {
   my ($self, $value) = @_; return $self->_crontab('mday', $value);
}

sub crontab_min {
   my ($self, $value) = @_; return $self->_crontab('min',  $value);
}

sub crontab_mon {
   my ($self, $value) = @_; return $self->_crontab('mon',  $value);
}

sub crontab_wday {
   my ($self, $value) = @_; return $self->_crontab('wday', $value);
}

sub current_condition {
   return shift->_eval_condition->[0];
}

sub delete {
   my $self = shift;

   $self->_delete_conditions if $self->condition;

   return $self->next::method;
}

sub insert {
   my $self = shift;

   $self->_update_dependent_fields;

   $self->validate unless App::MCP->env_var('bulk_insert');

   my $job = $self->next::method;

   $self->_create_conditions($job) if $self->condition;

   $self->_create_job_state($job);

   return $job;
}

sub is_executable_by {
   my ($self, $id) = @_; return $self->_is_permitted($id, [64, 8, 1]);
}

sub is_readable_by {
   my ($self, $id) = @_; return $self->_is_permitted($id, [256, 32, 4]);
}

sub is_writable_by {
   my ($self, $id) = @_; return $self->_is_permitted($id, [128, 16, 2]);
}

sub materialised_path_columns {
   return {
      parent => {
         parent_column                => 'parent_id',
         parent_fk_column             => 'id',
         materialised_path_column     => 'parent_path',
         include_self_in_path         => TRUE,
         include_self_in_reverse_path => TRUE,
         parent_relationship          => 'parent_box',
         children_relationship        => 'child_jobs',
         full_path                    => 'ancestors',
         reverse_full_path            => 'descendants',
         separator                    => SEPARATOR,
      },
   };
}

sub namespace {
   my $self  = shift;
   my $sep   = SEPARATOR;
   my @parts = split m{ $sep }mx, $self->job_name; pop @parts;
   my $ns    = join $sep, @parts; $ns //= NUL;

   return $ns;
}

sub permissions {
   my ($self, $perms) = @_;

   $self->_permissions($perms) if defined $perms;

   return sprintf '0%o', $self->_permissions;
}

sub should_start_now {
   my $self      = shift;
   my $crontab   = $self->crontab or return TRUE;
   my $last_time = $self->state ? $self->state->updated->epoch : 0;
   my $cron      = Algorithm::Cron->new(base => 'utc', crontab => $crontab);

   return time >= $cron->next_time($last_time) ? TRUE : FALSE;
}

sub sqlt_deploy_hook {
   my ($self, $st) = @_;

   $st->add_index(name => 'jobs_idx_job_name',  fields => ['job_name']);
   $st->add_index(name => 'jobs_idx_parent_id', fields => ['parent_id']);

  return;
}

sub update {
   my ($self, $columns) = @_;

   $self->set_inflated_columns($columns) if $columns;

   $self->_update_dependent_fields;

   $self->validate unless App::MCP->env_var('bulk_insert');

   my $job = $self->next::method;

   $self->_update_conditions($job) if $self->_condition_changed;

   return $job;
}

sub validation_attributes {
   return { # Keys: constraints, fields, and filters (all hashes)
      constraints      => {
         job_name      => {
            max_length => VARCHAR_MAX_SIZE,
            min_length => 1,
            pattern    => '\A [A-Za-z_][/0-9A-Za-z_]+ \z', } },
      fields           => {
         command       => { validate => 'isMandatory' },
         host          => { validate => 'isMandatory isValidHostname' },
         job_name      => {
            filters    => 'filterReplaceRegex',
            validate   => 'isMandatory isMatchingRegex isValidLength' },
         permissions   => { validate => 'isValidInteger' },
         user_name     => { validate => 'isMandatory isValidIdentifier' }, },
      filters          => {
         job_name      => { pattern => '[\%\*]', replace => NUL }, },
   };
}

# Private methods
sub _create_conditions {
   my ($self, $job) = @_;

   my $schema = $self->result_source->schema;

   $schema->resultset('JobCondition')->create_conditions($job);
   return;
}

sub _create_job_state {
   my $self   = shift;
   my $schema = $self->result_source->schema;

   return $schema->resultset('JobState')->find_or_create(@_);
}

sub _crontab {
   my ($self, $k, $v) = @_;

   my @names = CRONTAB_FIELD_NAMES;

   unless (defined $self->{_crontab}) {
      my @fields = split m{ \s+ }mx, $self->crontab;

      $self->{_crontab}->{$names[$_]} = ($fields[$_] // NUL) for (0 .. 4);
   }

   if (defined $v) {
      $self->{_crontab}->{$k} = $v;
      $self->crontab(join SPC, map {
         $self->{_crontab}->{$names[$_]}
      } 0 .. 4);
   }

   return $self->{_crontab}->{$k};
}

sub _delete_conditions {
   my $self   = shift;
   my $schema = $self->result_source->schema;

   $schema->resultset('JobCondition')->delete_conditions($self);
   return;
}

sub _eval_condition {
   my $self = shift;

   return [ TRUE, [] ] unless $self->condition;

   return $self->_parser->parse($self->condition, $self->namespace);
}

sub _is_permitted {
   my ($self, $user_id, $mask) = @_;

   my $perms = $self->_permissions;

   return TRUE if $perms & $mask->[2];

   my $user_rs = $self->result_source->schema->resultset('User');
   my $user    = $user_rs->find($user_id);

   return TRUE if $perms & $mask->[1]
      and is_member($self->group, map { $_->id } $user->roles);

   return TRUE if $perms & $mask->[0] and $self->owner == $user->id;

   return FALSE;
}

sub _update_conditions {
   my ($self, $job) = @_;

   $self->_delete_conditions;
   $self->_create_conditions($job);
   $self->_condition_changed(FALSE);
   return;
}

sub _update_dependent_fields {
   my $self         = shift;
   my $job_rs       = $self->result_source->resultset;
   my $dependencies = [];

   for my $job_name (@{$self->_eval_condition->[1]}) {
      my $job = $job_rs->find_by_key($job_name)
         or throw UnknownJob, [$job_name];

      push @{$dependencies}, $job->id;
   }

   $self->dependencies(join '/', sort { $a <=> $b } @{$dependencies});

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

=head2 insert

=head2 materialised_path_columns

=head2 name

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
