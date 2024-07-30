package App::MCP::Schema::Schedule::Result::BugComment;

use App::MCP::Constants qw( FALSE SQL_NOW TRUE );
use App::MCP::Util      qw( created_timestamp_data_type
                            foreign_key_data_type serial_data_type
                            text_data_type updated_timestamp_data_type );
use DBIx::Class::Moo::ResultClass;

extends 'App::MCP::Schema::Base';

my $class  = __PACKAGE__;
my $result = 'App::MCP::Schema::Schedule::Result';

$class->table('bug_comments');

$class->add_columns(
   id      => { %{serial_data_type()}, label => 'Comment ID' },
   bug_id  => foreign_key_data_type,
   user_id => {
      %{foreign_key_data_type()},
      display => 'owner.user_name',
      label   => 'Owner',
   },
   created => created_timestamp_data_type,
   updated => updated_timestamp_data_type,
   comment => text_data_type,
);

$class->set_primary_key('id');

$class->belongs_to('bug' => "${result}::Bug", 'bug_id');

$class->belongs_to('owner' => "${result}::User", 'user_id');

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
