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

   'GET|POST + /job/create + ?*'    => 'job/root/base/create',
   'GET|POST + /job/select + ?*'    => 'job/root/base/select',
   'POST     + /job/*/delete + ?*'  => 'job/root/base/delete',
   'GET|POST + /job/*/edit + ?*'    => 'job/root/base/edit',
   'GET      + /job/* + ?*'         => 'job/root/base/view',
   'GET      + /job + ?*'           => 'job/root/base/list',

   'GET|POST + /state/*/edit + ?*' => 'state/root/base/edit',
   'GET      + /state        + ?*' => 'state/root/base/view',

   'GET|POST + /user/create + ?*'       => 'user/root/base/create',
   'POST     + /user/*/delete + ?*'     => 'user/root/base/delete',
   'GET|POST + /user/*/edit + ?*'       => 'user/root/base/edit',
   'GET|POST + /user/*/password/* + ?*' => 'page/root/base/password_reset',
   'GET|POST + /user/*/password + ?*'   => 'page/root/base/password',
   'GET|POST + /user/*/profile + ?*'    => 'user/root/base/profile',
   'GET|POST + /user/*/totp/* + ?*'     => 'page/root/base/totp_reset',
   'GET      + /user/*/totp + ?*'       => 'user/root/base/totp',
   'GET      + /user/* + ?*'            => 'user/root/base/view',
   'GET      + /user + ?*'              => 'user/root/base/list',

   'GET      + /doc/configuration + ?*' => 'doc/root/base/configuration',
   'GET      + /doc/select + ?*'        => 'doc/root/base/select',
   'GET      + /doc/*.* + ?*'           => 'doc/root/base/view',
   'GET      + /doc + ?*'               => 'doc/root/base/list',

   'POST     + /logfile/*/clear + ?*' => 'logfile/root/clear_cache',
   'GET      + /logfile/*.* + ?*'     => 'logfile/root/base/view',
   'GET      + /logfile + ?*'         => 'logfile/root/base/list',

   'GET      + /access_denied + ?*'          => 'page/root/base/access_denied',
   'GET      + /changes + ?*'                => 'page/root/base/changes',
   'GET      + /footer/** + ?*'              => 'page/footer',
   'GET|POST + /login + ?*'                  => 'page/root/base/login',
   'POST     + /logout + ?*'                 => 'page/root/logout',
   'GET|POST + /register/* | /register + ?*' => 'page/root/base/register',

   'GET    + /** + ?*' => 'page/root/not_found',
   'GET    + ?*'       => 'page/root/default',
   'HEAD   + ?*'       => 'page/root/not_found',
   'PUT    + ?*'       => 'page/root/not_found',
   'POST   + ?*'       => 'page/root/not_found',
   'DELETE + ?*'       => 'page/root/not_found',
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
