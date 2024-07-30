package App::MCP::Schema::Schedule::Result::Bug;

use App::MCP::Constants qw( BUG_STATE_ENUM FALSE SQL_NOW TRUE );
use App::MCP::Util      qw( created_timestamp_data_type enumerated_data_type
                            foreign_key_data_type
                            nullable_foreign_key_data_type serial_data_type
                            text_data_type updated_timestamp_data_type );
use DBIx::Class::Moo::ResultClass;

extends 'App::MCP::Schema::Base';

my $class  = __PACKAGE__;
my $result = 'App::MCP::Schema::Schedule::Result';

$class->table('bugs');

$class->add_columns(
   id          => { %{serial_data_type()}, label => 'Bug ID' },
   title       => text_data_type,
   description => text_data_type,
   user_id     => {
      %{foreign_key_data_type()},
      display  => 'owner.user_name',
      label    => 'Owner',
   },
   created     => created_timestamp_data_type,
   updated     => updated_timestamp_data_type,
   state       => enumerated_data_type( BUG_STATE_ENUM, 'open' ),
   assigned_id => {
      %{nullable_foreign_key_data_type()},
      display  => 'assigned.user_name',
      label    => 'Assigned',
   },
);

$class->set_primary_key('id');

$class->belongs_to('owner' => "${result}::User", 'user_id');

$class->belongs_to('assigned' => "${result}::User", 'assigned_id');

$class->has_many('comments' => "${result}::BugComment", 'bug_id');

sub insert {
   my $self    = shift;
   my $columns = { $self->get_inflated_columns };

   $columns->{created} = SQL_NOW;
   $self->set_inflated_columns($columns);

   return $self->next::method;
}

sub update {
   my ($self, $columns) = @_;

   $self->set_inflated_columns($columns) if $columns;

   $columns = { $self->get_inflated_columns };
   $columns->{updated} = SQL_NOW;
   $self->set_inflated_columns($columns);
   return $self->next::method;
}

use namespace::autoclean;

1;
