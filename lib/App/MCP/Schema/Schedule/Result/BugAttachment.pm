package App::MCP::Schema::Schedule::Result::BugAttachment;

use App::MCP::Constants qw( FALSE SQL_NOW TRUE );
use App::MCP::Util      qw( created_timestamp_data_type
                            foreign_key_data_type nullable_foreign_key_data_type
                            serial_data_type text_data_type
                            updated_timestamp_data_type );
use DBIx::Class::Moo::ResultClass;

extends 'App::MCP::Schema::Base';
with    'App::MCP::Role::FileMeta';

my $class  = __PACKAGE__;
my $result = 'App::MCP::Schema::Schedule::Result';

$class->table('bug_attachments');

$class->add_columns(
   id         => { %{serial_data_type()}, label => 'Attachment ID' },
   bug_id     => foreign_key_data_type,
   user_id    => {
      %{foreign_key_data_type()},
      display => 'owner.user_name',
      label   => 'Owner',
   },
   comment_id => nullable_foreign_key_data_type,
   created    => created_timestamp_data_type,
   updated    => updated_timestamp_data_type,
   path       => text_data_type,
);

$class->set_primary_key('id');

$class->belongs_to('bug' => "${result}::Bug", 'bug_id');

$class->belongs_to('owner' => "${result}::User", 'user_id');

$class->belongs_to('comment' => "${result}::BugComment", 'comment_id');

has '+meta_config_attr' => default => 'bug_attachments';

sub content_path {
   my ($self, $options) = @_;

   my $config = $self->result_source->schema->config;
   my $base   = $self->meta_directory($config, $self->bug_id);

   return $base->catfile($self->path);
}

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
