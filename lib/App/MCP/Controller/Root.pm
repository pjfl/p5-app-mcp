package App::MCP::Controller::Root;

use Web::Simple;

with 'Web::Components::Role';
with 'Web::Components::ReverseMap';

has '+moniker' => default => 'z_root';

sub dispatch_request {
return (
   'GET|POST + /api/** + ?*' => sub {['api/root/dispatch', @_]},

   'GET|POST + /job/create + ?*' => sub {['job/root/base/create', @_]},
   'GET|POST + /job/*/edit + ?*' => sub {['job/root/base/edit',   @_]},
   'POST + /job/*/delete + ?*'   => sub {['job/root/base/delete', @_]},
   'GET + /job/* + ?*'           => sub {['job/root/base/view',   @_]},
   'GET + /job + ?*'             => sub {['job/root/base/list',   @_]},

   'GET  + /state + ?*' => sub {['state/root/base/view', @_]},

   'GET|POST + /user/create + ?*'     => sub {['user/root/base/create',    @_]},
   'POST     + /user/*/delete + ?*'   => sub {['user/root/base/delete',    @_]},
   'GET|POST + /user/*/edit + ?*'     => sub {['user/root/base/edit',      @_]},
   'GET|POST + /user/*/password/* + ?*'
                                 => sub {['page/root/base/password_reset', @_]},
   'GET|POST + /user/*/password + ?*' => sub {['page/root/base/password',  @_]},
   'GET|POST + /user/*/profile + ?*'  => sub {['user/root/base/profile',   @_]},
   'GET|POST + /user/*/totp/* + ?*'   => sub {['page/root/base/totp_reset',@_]},
   'GET      + /user/*/totp + ?*'     => sub {['user/root/base/totp',      @_]},
   'GET      + /user/* + ?*'          => sub {['user/root/base/view',      @_]},
   'GET      + /user + ?*'            => sub {['user/root/base/list',      @_]},

   'GET      + /access_denied + ?*'
                               => sub {['page/root/base/access_denied', @_]},
   'GET      + /changes + ?*'  => sub {['page/root/base/changes',       @_]},
   'GET      + /configuration + ?*'
                               => sub {['page/root/base/configuration', @_]},
   'GET|POST + /login + ?*'    => sub {['page/root/base/login',         @_]},
   'POST     + /logout + ?*'   => sub {['page/root/logout',             @_]},
   'GET      + /property + ?*' => sub {['page/root/object_property',    @_]},
   'GET|POST + /register/* | /register + ?*'
                               => sub {['page/root/base/register',      @_]},

   'GET    + /** + ?*' => sub {['page/root/not_found', @_]},
   'GET    + ?*'       => sub {['page/root/default',   @_]},
   'HEAD   + ?*'       => sub {['page/root/not_found', @_]},
   'PUT    + ?*'       => sub {['page/root/not_found', @_]},
   'POST   + ?*'       => sub {['page/root/not_found', @_]},
   'DELETE + ?*'       => sub {['page/root/not_found', @_]},
)}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
