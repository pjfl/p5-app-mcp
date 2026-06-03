package App::MCP::Schema::Schedule::Result::Job;

use overload '""' => sub { shift->_as_string },
             '+'  => sub { shift->_as_number }, fallback => 1;
use parent 'App::MCP::Schema::Base';

use App::MCP::Constants    qw( EXCEPTION_CLASS CRONTAB_FIELD_NAMES FALSE
                               JOB_TYPE_ENUM NUL SEPARATOR SPC TRUE
                               VARCHAR_MAX_SIZE );
use App::MCP::Util         qw( boolean_data_type enumerated_data_type
                               foreign_key_data_type
                               nullable_foreign_key_data_type
                               nullable_text_data_type
                               nullable_varchar_data_type integer_data_type
                               integer_id_data_type serial_data_type
                               set_on_create_datetime_data_type
                               trigger_output_handler truncate
                               varchar_data_type );
use Class::Usul::Cmd::Util qw( includes trim );
use HTML::Forms::Util      qw( int2rwx );
use Ref::Util              qw( is_arrayref is_plain_hashref );
use Scalar::Util           qw( blessed );
use Unexpected::Functions  qw( throw UnknownJob );
use Algorithm::Cron;
use App::MCP::ExpressionParser;
use DBIx::Class::Moo::ResultClass;

=pod

=head1 Name

App::MCP::Schema::Schedule::Result::Job - Job definition

=head1 Synopsis

   use Moo;

   with 'App::MCP::Role::Schema';

   my $job = $self->schema->resultset('Job')->new_result({});

=head1 Description

Job definition. Instances of this class are stored in the C<jobs> table

=head1 Configuration and Environment

Defines the following attributes/columns;

=over 3

=item C<id>

Auto incrementing primary key

=item C<job_name>

Unique name for the job. Maximum length C<VARCHAR_MAX_SIZE>. Minimum length
C<3>. Can only contain C<[a-zA-Z0-9_/]>

Unique index name C<jobs_job_name_uniq>

=item C<description>

Nullable text field which describes the job

=item C<type>

An enumerated type. Either C<box> or C<job>. Defaults to C<box>

=item C<parent_id>

The C<id> of the parent box. This can be null

=item C<created>

Date and time this job was created. Value set automatically to datebase time

=item C<owner_id>

The id of the owner of the job

=item C<group_id>

The user group to which the job belongs

=item C<permissions>

User/group/other read/write/execute permissions for the job

=item C<condition>

An evaluatable expression which (if set) needs to be true before the job will
start

=item C<crontab>

These are the optional time related parameters used to start the job. The
string has the same format (five space separated fields) as the one found in
the OS level C<crontab> file

Accessors/mutators are defined for each of the five values so this field is
not set directly

=item C<user_name>

Name of the OS level user to run the command as

=item C<host>

Hostname on which to run the command

=item C<command>

The command to run

=item C<directory>

Directory to change to before executing the command

=item C<expected_rv>

The expected return value of the command. Defaults to zero

=item C<delete_after>

A boolean which if true causes the job definition to be deleted upon
completion

=item C<auto_hold>

Boolean which if true causes the job to enter an C<on_hold> state when
activated.  Defaults to false

=item C<max_runtime>

Maximum runtime for the job in seconds. Defaults to zero which means no time
limit

=item C<nretrys>

If the job fails how many times should it be restarted? Defaults to zero which
means no restart is attempted

=item C<load_limit>

If set this number is used to limit the number of simultaneous jobs the
scheduler will run

=item C<err_file>

If set the C<stderr> from the command will be redirected here

=item C<out_file>

If set the C<stdout> from the command will be redirected here

=item C<parent_path>

Used by the materialised path component

=item C<path_depth>

Used to limit the number of jobs returned to the state diagram query

=item C<dependencies>

List of job names that this job depends on

=cut

my $class  = __PACKAGE__;
my $result = 'App::MCP::Schema::Schedule::Result';

$class->table('jobs');

$class->load_components('+App::MCP::MaterialisedPath');

$class->add_columns(
   id           => { %{serial_data_type()}, hidden => TRUE },
   job_name     => { %{varchar_data_type()}, label => 'Job Name' },
   description  => nullable_text_data_type,
   created      => set_on_create_datetime_data_type,
   parent_id    => {
      %{nullable_foreign_key_data_type()},
      display => 'parent_box.job_name',
      label   => 'Parent Box'
   },
   type         => enumerated_data_type(JOB_TYPE_ENUM, 'box'),
   owner_id     => {
      %{foreign_key_data_type(1, 'owner')},
      display => 'owner_rel.user_name',
      label   => 'Owner'
   },
   group_id     => {
      %{foreign_key_data_type(1, 'group')},
      display => 'group_rel.role_name',
      label   => 'Group'
   },
   permissions  => {
      data_type     => 'smallint',
      default_value => 488,
      display       => sub { int2rwx shift->result->permissions },
      is_nullable   => FALSE,
   },
   condition    => {
      %{nullable_varchar_data_type()},
      accessor  => '_condition',
   },
   crontab      => nullable_varchar_data_type(127),
   dependencies => { %{nullable_varchar_data_type()}, hidden => TRUE },
   parent_path  => { %{nullable_varchar_data_type()}, hidden => TRUE },
   path_depth   => { %{integer_id_data_type(0)}, hidden => TRUE },
   auto_hold    => { %{boolean_data_type()}, label => 'Auto. Hold' },
   user_name    => { %{varchar_data_type(32, 'mcp')}, label => 'User Name' },
   host         => varchar_data_type(64, 'localhost'),
   directory    => nullable_varchar_data_type,
   command      => nullable_varchar_data_type,
   err_file     => { %{nullable_varchar_data_type()}, label => 'Error File' },
   out_file     => { %{nullable_varchar_data_type()}, label => 'Output File' },
   expected_rv  => { %{integer_id_data_type(0)}, label => 'Expected RV' },
   nretrys      => { %{integer_id_data_type(0)}, label => 'Num. Retrys' },
   delete_after => { %{boolean_data_type()}, label => 'Delete After' },
   max_runtime  => { %{integer_data_type(0)}, label => 'Max. Runtime' },
   load_limit   => {
      data_type     => 'numeric',
      default_value => 0,
      label         => 'Load Limit',
   },
);


$class->set_primary_key('id');

$class->add_unique_constraint('jobs_job_name_uniq', ['job_name']);

=back

=head1 Relations

Defines the following relations;

=over 3

=item C<parent_box>

Left join on the C<jobs> table. This job belongs to the parent if there is one

=item C<child_jobs>

This job may have zero, one, or more child jobs whose C<parent_id> match this
jobs C<id>

=item C<dependents>

This job may have zero, one, or more L<job
conditions|App::MCP::Schema::Schedule::Result::JobCondition> on which this
job's start condition depends

=item C<events>

This job may have zero, one, or more
L<events|App::MCP::Schema::Schedule::Result::Event> pending application to this
job

=item C<processed_events>

This job may have zero, one, or more
L<events|App::MCP::Schema::Schedule::Result::ProcessedEvent> that were applied
to this job

=item C<state>

This job might have a L<job state|App::MCP::Schema::Schedule::Result::JobState>

=item C<owner_rel>

This job belongs to a L<user|App::MCP::Schema::Schedule::Result::User> object

=item C<group_rel>

This job belongs to a L<role|App::MCP::Schema::Schedule::Result::Role> object

=cut

$class->belongs_to( parent_box       => "${result}::Job",         'parent_id',
                    { join_type      => 'left' } );
$class->has_many  ( child_jobs       => "${result}::Job",         'parent_id' );
$class->has_many  ( dependents       => "${result}::JobCondition",   'job_id' );
$class->has_many  ( events           => "${result}::Event",          'job_id' );
$class->has_many  ( processed_events => "${result}::ProcessedEvent", 'job_id' );
$class->might_have( state            => "${result}::JobState",       'job_id' );
$class->belongs_to( owner_rel        => "${result}::User",         'owner_id' );
$class->belongs_to( group_rel        => "${result}::Role",         'group_id' );

# Private attributes
has '_condition_changed' => is => 'rw', default => FALSE;

has '_expression_parser' =>
   is      => 'lazy',
   default => sub {
      my $self    = shift;
      my $job_rs  = $self->result_source->resultset;
      my $options = { external => $job_rs, predicates => $job_rs->predicates };

      return App::MCP::ExpressionParser->new($options);
   };

=back

=head1 Subroutines/Methods

Defines the following methods;

=over 3

=item C<condition>

   $condition_string = $self->condition($condition_string?);

Accessor/mutator for the C<condition> attribute. Changes trigger an update of
the related L<job condition|App::MCP::Schema::Schedule::Result::JobCondition>

=cut

sub condition {
   my ($self, $value) = @_;

   my $condition = $self->_condition;

   return $condition unless defined $value;

   $self->_condition_changed(TRUE) if !$condition || $condition ne $value;

   return $self->_condition($value);
}

=item C<crontab_hour>

   $hour = $self->crontab_hour($hour?);

Accessor/mutator for the C<crontab> attribute

=cut

sub crontab_hour {
   my ($self, $value) = @_; return $self->_crontab('hour', $value);
}

=item C<crontab_mday>

   $month_day = $self->crontab_mday($month_day?);

Accessor/mutator for the C<crontab> attribute

=cut

sub crontab_mday {
   my ($self, $value) = @_; return $self->_crontab('mday', $value);
}

=item C<crontab_min>

   $minute = $self->crontab_min($minute?);

Accessor/mutator for the C<crontab> attribute

=cut

sub crontab_min {
   my ($self, $value) = @_; return $self->_crontab('min',  $value);
}

=item C<crontab_mon>

   $month = $self->crontab_mon($month?);

Accessor/mutator for the C<crontab> attribute

=cut

sub crontab_mon {
   my ($self, $value) = @_; return $self->_crontab('mon',  $value);
}

=item C<crontab_wday>

   $week_day = $self->crontab_wday($week_day?);

Accessor/mutator for the C<crontab> attribute

=cut

sub crontab_wday {
   my ($self, $value) = @_; return $self->_crontab('wday', $value);
}

=item C<delete>

   $job = $self->delete;

Calls the inherited method in the base class. Also deletes the associated
L<condition|App::MCP::Schema::Schedule::Result::JobCondition> objects

Returns this now deleted job object

=cut

sub delete {
   my $self = shift;

   $self->_delete_conditions if $self->condition;

   return $self->next::method;
}

=item C<has_active_jobs>

   $bool = $self->has_active_jobs;

Returns true if this job is a box containing jobs that are C<active>,
C<starting>, or C<running>. Returns false otherwise

=cut

sub has_active_jobs {
   my $self     = shift;
   my $options  = { prefetch => 'state' };
   my $job_rs   = $self->result_source->schema->resultset('Job');
   my $children = [$job_rs->search({ parent_id => $self->id }, $options)->all];

   for my $name (map { $_->state->name } @{$children}) {
      return TRUE if includes $name, [qw(active starting running)];
   }

   return FALSE;
}

=item C<insert>

   $job = $self->insert;

Calls the inherited method in the base class. Also updates the C<dependencies>
field, creates any associated
L<condition|App::MCP::Schema::Schedule::Result::JobCondition> objects, and
initialises the L<job state|App::MCP::Schema::Schedule::Result::JobState>
object

Returns this newly inserted job object

=cut

sub insert {
   my $self = shift;

   $self->_update_dependent_fields;

   $self->validate unless App::MCP->env_var('bulk_insert');

   my $job = $self->next::method;

   $self->_create_conditions($job) if $self->condition;

   $self->_create_job_state($job);

   return $job;
}

=item C<is_executable_by>

   $bool = $self->is_executable_by($user);

The C<user> argument can be one of;

=over 3

=item A L<user|App::MCP::Schema::Schedule::Result::User> object

=item A hash reference with the keys C<owner> and C<groups>

=item A C<username>

=item A C<user_id>

=item An C<email_address>

=back

Returns true if this job is executable by the given C<user>

=cut

sub is_executable_by {
   my ($self, $user) = @_; return $self->_is_permitted($user, [64, 8, 1]);
}

=item C<is_readable_by>

   $bool = $self->is_readable_by($user);

Returns true if this job is readable by the given C<user>

=cut

sub is_readable_by {
   my ($self, $user) = @_; return $self->_is_permitted($user, [256, 32, 4]);
}

=item C<is_writable_by>

   $bool = $self->is_writable_by($user);

Returns true if this job is writable (updateable) by the given C<user>

=cut

sub is_writable_by {
   my ($self, $user) = @_; return $self->_is_permitted($user, [128, 16, 2]);
}

=item C<label>

   $label = $self->label

Returns a string suitable for use as a label to identify this job

=cut

sub label {
   my $self = shift; return sprintf '%s(%s)', $self->job_name, $self->id;
}

=item C<materialised_path_columns>

   $hash_ref = $self->materialised_path_columns;

Returns a static hash reference used by the L<materialised
path|App::MCP::MaterialisedPath> component

=cut

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

=item C<namespace>

   $namespace_string = $self->namespace;

Splits the C<job_name> on C<SEPARATOR> (a slash). The first part is the
C<namespace>. If the C<job_name> contains no C<SEPARATOR> the C<namspace>
is C<NUL>

This "feature" may go away. Could also be made private

=cut

sub namespace {
   my $self  = shift;
   my $sep   = SEPARATOR;
   my @parts = split m{ $sep }mx, ($self->job_name // NUL); pop @parts;
   my $ns    = join $sep, @parts; $ns //= NUL;

   return $ns;
}

=item C<should_start_now>

   $bool = $self->should_start_now;

Returns true if the C<crontab> attribute evaluates to true

=cut

sub should_start_now {
   my $self      = shift;
   my $crontab   = $self->crontab or return TRUE;
   my $cron      = Algorithm::Cron->new(base => 'local', crontab => $crontab);
   my $last_time = 0;

   if ($self->state) {
      my $updated = $self->state->updated;
      my $tz      = $self->result_source->schema->config->local_tz;

      $updated->set_time_zone($tz);
      $last_time = $updated->epoch;
   }

   return time >= $cron->next_time($last_time) ? TRUE : FALSE;
}

=item C<sqlt_deploy_hook>

   $self->sqlt_deploy_hook($statement_handle);

Called when the schema is deployed. This adds indexes for C<job_name>
and C<parent_id>

=cut

sub sqlt_deploy_hook {
   my ($self, $st) = @_;

   $st->add_index(name => 'jobs_idx_job_name',  fields => ['job_name']);
   $st->add_index(name => 'jobs_idx_parent_id', fields => ['parent_id']);

  return;
}

=item C<start_condition>

   $bool = $self->start_condition;

Returns true if the expression parser evaluates the start condition true

=cut

sub start_condition {
   return shift->_eval_condition->[0];
}

=item C<update>

   $job = $self->update(\%columns?);

Calls the inherited method in the base class. Also updates the C<dependencies>
field, and updates any associated
L<condition|App::MCP::Schema::Schedule::Result::JobCondition> objects if the
C<condition> attribute has changed

Returns this updated job object

=cut

sub update {
   my ($self, $columns) = @_;

   my $sep  = SEPARATOR;
   my $path = { $self->get_inflated_columns }->{parent_path};

   $columns //= {};
   $columns->{path_depth} = () = split m{ $sep }mx, $path, -1;
   $self->set_inflated_columns($columns);

   $self->_update_dependent_fields;

   $self->validate unless App::MCP->env_var('bulk_insert');

   my $job = $self->next::method;

   $self->_update_conditions($job) if $self->_condition_changed;

   return $job;
}

=item C<validation_attributes>

   $hash_ref = $self->validation_attributes;

Returns a static hash reference of keys/values used by L<Data::Validation>
to validate some of this objects attributes. This provides a finer level of
error messaging than is availiable to the API create job method

=cut

sub validation_attributes {
   return { # Keys: constraints, fields, and filters (all hashes)
      constraints      => {
         job_name      => {
            max_length => VARCHAR_MAX_SIZE,
            min_length => 3,
            pattern    => '\A [A-Za-z_]+ [/0-9A-Za-z_]+ \z', } },
      fields           => {
         host          => { validate => 'isValidHostname' },
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
sub _as_number {
   return shift->id;
}

sub _as_string {
   return shift->job_name;
}

sub _create_conditions {
   my ($self, $job) = @_;

   my $schema = $self->result_source->schema;

   $schema->resultset('JobCondition')->create_conditions($job);
   return;
}

sub _create_job_state {
   my ($self, $job) = @_;

   my $schema    = $self->result_source->schema;
   my $job_state = $schema->resultset('JobState')->find_or_create($job);

   trigger_output_handler $schema->config if $job_state->name eq 'active';

   return $job_state;
}

sub _crontab {
   my ($self, $k, $v) = @_;

   my @names = CRONTAB_FIELD_NAMES;

   unless (defined $self->{_crontab}) {
      my @fields = split m{ \s+ }mx, $self->crontab // NUL;

      $self->{_crontab}->{$names[$_]} = ($fields[$_] // NUL) for (0 .. 4);
   }

   if (defined $v) {
      $self->{_crontab}->{$k} = $v;
      my $crontab = join SPC, map { $self->{_crontab}->{$names[$_]} } 0 .. 4;

      $self->crontab(trim($crontab));
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

   return $self->_expression_parser->parse($self->condition, $self->namespace);
}

sub _is_permitted {
   my ($self, $id_or_user, $mask) = @_;

   my ($groups, $owner);

   if (blessed $id_or_user) {
      $owner  = $id_or_user->id;
      $groups = $id_or_user->groups;
   }
   elsif (is_plain_hashref $id_or_user) {
      $owner  = $id_or_user->{owner};
      $groups = $id_or_user->{groups};
   }
   else {
      my $options = { prefetch => 'profile' };
      my $user_rs = $self->result_source->schema->resultset('User');
      my $user    = $user_rs->find_by_key($id_or_user, $options);

      $owner  = $user->id;
      $groups = $user->groups;
   }

   my $perms = $self->permissions;

   return $perms & $mask->[0] ? TRUE : FALSE if $self->owner == $owner;

   my $group_name = $self->_lookup_group_name($self->group);

   return $perms & $mask->[1] ? TRUE : FALSE if includes $group_name, $groups;

   return $perms & $mask->[2] ? TRUE : FALSE;
}

sub _lookup_group_name {
   my ($self, $group_id) = @_;

   my $rs    = $self->result_source->schema->resultset('Role');
   my $group = $rs->find_by_key($group_id);

   return $group->role_name;
}

sub _update_conditions {
   my ($self, $job) = @_;

   $self->_delete_conditions;
   $self->_create_conditions($job);
   $self->_condition_changed(FALSE);
   return;
}

sub _update_dependent_fields {
   my $self      = shift;
   my $job_rs    = $self->result_source->resultset;
   my $dep_names = $self->_eval_condition->[1];

   unless ($dep_names->[0]) {
      $self->dependencies(NUL);
      return;
   }

   my $where        = { job_name => { -in => $dep_names } };
   my $dependencies = [];

   for my $job ($job_rs->search($where, { columns => ['id'] })->all) {
      push @{$dependencies}, $job->id;
   }

   $self->dependencies(join '/', sort { $a <=> $b } @{$dependencies});

   return;
}

use namespace::autoclean;

1;

__END__

=back

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Algorithm::Cron>

=item L<App::MCP::ExpressionParser>

=item L<App::MCP::MaterialisedPath>

=item L<DBIx::Class::Moo::ResultClass>

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

Copyright (c) 2025 Peter Flanigan. All rights reserved

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
