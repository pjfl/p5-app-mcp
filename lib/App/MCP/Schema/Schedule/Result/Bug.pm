package App::MCP::Schema::Schedule::Result::Bug;

use App::MCP::Constants qw( BUG_STATE_ENUM );
use App::MCP::Util      qw( enumerated_data_type foreign_key_data_type
                            serial_data_type text_data_type );
use DBIx::Class::Moo::ResultClass;

extends 'App::MCP::Schema::Base';

my $class  = __PACKAGE__;
my $result = 'App::MCP::Schema::Schedule::Result';

$class->table('bugs');

$class->add_columns(
   id          => { %{serial_data_type()}, label => 'Bug ID' },
   state       => enumerated_data_type( BUG_STATE_ENUM, 'open' ),
   user_id     => {
      %{foreign_key_data_type()},
      display  => 'user.user_name',
      label    => 'User',
   },
   description => text_data_type,
);

$class->set_primary_key('id');

$class->belongs_to('user' => "${result}::User", 'user_id');

use namespace::autoclean;

1;
