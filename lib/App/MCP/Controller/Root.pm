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

   'GET  + /job_chooser    + ?*' => sub {['job/chooser',         @_]},
   'GET  + /job_grid_rows  + ?*' => sub {['job/chooser_rows',    @_]},
   'GET  + /job_grid_table + ?*' => sub {['job/chooser_table',   @_]},
   'GET  + /job_state/**   + ?*' => sub {['job/job_state',       @_]},
   'GET  + /state_diagram      ' => sub {['state/diagram',       @_]},

   'GET|POST + /user/*/password/* + ?*'
                                 => sub {['page/root/base/password_reset', @_]},
   'GET|POST + /user/*/password + ?*' => sub {['page/root/base/password',  @_]},

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
