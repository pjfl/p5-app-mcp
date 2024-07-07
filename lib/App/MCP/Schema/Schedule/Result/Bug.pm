package App::MCP::Schema::Schedule::Result::Bug;

use App::MCP::Constants    qw( BUG_STATE_ENUM );
use App::MCP::Util         qw( enumerated_data_type foreign_key_data_type
                               serial_data_type text_data_type );
use Class::Usul::Cmd::Util qw( now_dt );
use DBIx::Class::Moo::ResultClass;

extends 'App::MCP::Schema::Base';

my $class  = __PACKAGE__;
my $result = 'App::MCP::Schema::Schedule::Result';

$class->table('bugs');

$class->add_columns(
   id          => { %{serial_data_type()}, label => 'Bug ID' },
   created     => {
      cell_traits   => ['DateTime'],
      data_type     => 'timestamp',
      set_on_create => TRUE,
      timezone      => 'UTC',
   },
   updated => {
      cell_traits => ['DateTime'],
      data_type   => 'timestamp',
      is_nullable => TRUE,
      timezone    => 'UTC',
   },
   user_id     => {
      %{foreign_key_data_type()},
      display  => 'owner.user_name',
      label    => 'Owner',
   },
   state       => enumerated_data_type( BUG_STATE_ENUM, 'open' ),
   title       => text_data_type,
   description => text_data_type,
);

$class->set_primary_key('id');

$class->belongs_to('owner' => "${result}::User", 'user_id');

sub insert {
   my $self    = shift;
   my $columns = { $self->get_inflated_columns };

   $columns->{created} = now_dt;
   $self->set_inflated_columns($columns);

   return $self->next::method;
}

sub update {
   my ($self, $columns) = @_;

   $self->set_inflated_columns($columns) if $columns;

   $columns = { $self->get_inflated_columns };
   $columns->{updated} = now_dt;
   $self->set_inflated_columns($columns);
   return $self->next::method;
}

use namespace::autoclean;

1;
