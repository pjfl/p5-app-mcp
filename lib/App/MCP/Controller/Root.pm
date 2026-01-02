package App::MCP::Controller::Root;

use Web::Components::Util qw( build_routes );
use Web::Simple;

with 'Web::Components::Role';
with 'Web::Components::ReverseMap';

has '+moniker' => default => 'z_root';

sub dispatch_request { build_routes
   'GET|POST + /api/**.* + ?*' => 'api/root/dispatch',

   'GET      + /job/*/history/run/* | /job/*/history/run + ?*'
                                                   => 'history/root/base/view',
   'GET      + /job/*/history | /job/history + ?*' => 'history/root/base/list',

   'GET|POST + /job/create + ?*'   => 'job/root/base/create',
   'GET|POST + /job/select + ?*'   => 'job/root/base/select',
   'POST     + /job/*/delete + ?*' => 'job/root/base/delete',
   'GET|POST + /job/*/edit + ?*'   => 'job/root/base/edit',
   'GET      + /job/* + ?*'        => 'job/root/base/view',
   'GET      + /job + ?*'          => 'job/root/base/list',

   'GET|POST + /state/*/edit + ?*' => 'state/root/base/edit',
   'GET      + /state        + ?*' => 'state/root/base/view',

   'GET|POST + /user/create + ?*'       => 'user/root/base/create',
   'POST     + /user/*/delete + ?*'     => 'user/root/user/delete',
   'GET|POST + /user/*/edit + ?*'       => 'user/root/user/edit',
   'GET      + /user/*/password/* + ?*' => 'misc/root/user/password_update',
   'GET|POST + /user/*/password + ?*'   => 'misc/root/user/password',
   'GET|POST + /user/*/profile + ?*'    => 'user/root/user/profile',
   'GET|POST + /user/*/totp/reset + ?*' => 'misc/root/user/totp_reset',
   'GET      + /user/*/totp/* + ?*'     => 'misc/root/user/totp',
   'GET      + /user/*/totp + ?*'       => 'user/root/user/totp',
   'GET      + /user/* + ?*'            => 'user/root/user/view',
   'GET      + /user + ?*'              => 'user/root/base/list',

   'GET      + /doc/configuration + ?*' => 'doc/root/base/configuration',
   'GET      + /doc/select + ?*'        => 'doc/root/base/select',
   'GET      + /doc/*.* + ?*'           => 'doc/root/base/view',
   'GET      + /doc + ?*'               => 'doc/root/base/list',

   'POST     + /logfile/*/clear + ?*' => 'logfile/root/clear_cache',
   'GET      + /logfile/*.* + ?*'     => 'logfile/root/base/view',
   'GET      + /logfile + ?*'         => 'logfile/root/base/list',

   'GET      + /changes + ?*'      => 'misc/root/base/changes',
   'POST     + /login + ?*'        => 'misc/root/base/login_dispatch',
   'GET      + /login + ?*'        => 'misc/root/base/login',
   'POST     + /logout + ?*'       => 'misc/root/logout',
   'GET      + /register/* + ?*'   => 'misc/root/base/create_user',
   'GET|POST + /register + ?*'     => 'misc/root/base/register',
   'GET      + /unauthorised + ?*' => 'misc/root/base/unauthorised',

   'GET + /footer/** + ?*' => 'misc/footer',

   'GET    + /** + ?*' => 'misc/root/not_found',
   'GET    + ?*'       => 'misc/root/default',
   'HEAD   + ?*'       => 'misc/root/not_found',
   'PUT    + ?*'       => 'misc/root/not_found',
   'POST   + ?*'       => 'misc/root/not_found',
   'DELETE + ?*'       => 'misc/root/not_found',
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
