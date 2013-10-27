# @(#)Ident: 11user.t 2013-10-22 00:50 pjf ;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 6 $ =~ /\d+/gmx );
use File::Spec::Functions   qw( catdir updir );
use FindBin                 qw( $Bin );
use lib                 catdir( $Bin, updir, 'lib' );

use Module::Build;
use Test::More;

my $notes = {}; my $perl_ver;

BEGIN {
   my $builder = eval { Module::Build->current };
      $builder and $notes = $builder->notes;
      $perl_ver = $notes->{min_perl_version} || 5.008;
}

use Test::Requires "${perl_ver}";

use_ok 'App::MCP::Schema';

my $factory = App::MCP::Schema->new( appclass => 'App::MCP', noask => 1 );
my $schema  = $factory->schedule;

my $rs   = $schema->resultset( 'User' );
my $user = $rs->search( { username => 'unknown' } )->first;

$user and $user->delete;
$user = $rs->create( {
   active => 1, password => 'none', username => 'unknown' } );

ok $user->id > 0, 'Creates a user';

$rs = $schema->resultset( 'Role' );

my $role = $rs->search( { rolename => 'unknown' } )->first;

$role and $role->delete; $role = $rs->create( { rolename => 'unknown' } );

ok $role->id > 0, 'Create a role';

$rs = $schema->resultset( 'UserRole' );

my $user_role = $rs->search( { user_id => $user->id } )->first;

$user_role and $user_role->delete; $user_role = $user->add_member_to( $role );

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
