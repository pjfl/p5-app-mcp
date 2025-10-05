use t::boilerplate;

use Test::More;
use Test::Memory::Cycle;

{  package TestApp;

   use Web::Simple;
   use Moo;

   with 'App::MCP::Role::Config';
   with 'App::MCP::Role::Log';
   with 'Web::Components::Loader';

   sub _build__factory {
      my $self = shift;

      return Web::ComposableRequest->new(
         buildargs => $self->factory_args,
         config    => $self->config->request,
      );
   }
}

my $app   = TestApp->new({ appclass => 'App::MCP' });
my $model = $app->models->{job};
my $view  = $app->views->{table};
my $env = {
   CONTENT_TYPE         => 'text/plain',
   HTTP_ACCEPT_LANGUAGE => 'en-gb,en;q=0.7,de;q=0.3',
   HTTP_HOST            => 'localhost:5000',
   PATH_INFO            => '/mcp/job',
   QUERY_STRING         => 'tablename=job',
   REMOTE_ADDR          => '127.0.0.1',
   REQUEST_METHOD       => 'GET',
   SERVER_PROTOCOL      => 'HTTP/1.1',
   'psgix.logger'       => sub { warn $_[0]->{message}."\n" },
   'psgix.session'      => {
      authenticated => 1, role => 'edit', username => 'mcp'
   },
};
my $req     = $app->new_from_simple_request({}, $env);
my $context = $model->get_context({ request => $req });

$model->root($context);
$model->base($context);
$model->list($context);

my $nav   = $context->stash('nav');
my $table = $context->stash('table');

like $nav->render, qr{ class="navigation }mx, 'Navigation render';

like $table->render, qr{ class="state-table" }mx, 'Table render';

$context->stash('_serialise_table' => {
   format => 'json',
   no_filename => 1,
   serialiser_args => {
      disable_paging => 0,
      serialise_meta => 0,
   },
   table => $table,
});

$view->serialize($context);

my $res   = $context->response;
my $stash = $context->stash;

my $rs   = $context->model('Job');
my $jobs = [$rs->all];

memory_cycle_ok( $app, 'Application has no memory cycles' );
memory_cycle_ok( $model, 'Model has no memory cycles' );
memory_cycle_ok( $view, 'View has no memory cycles' );
memory_cycle_ok( $req, 'Request has no memory cycles' );
memory_cycle_ok( $context, 'Context has no memory cycles' );
memory_cycle_ok( $nav, 'Navigation has no memory cycles' );
memory_cycle_ok( $table, 'Table has no memory cycles' );
memory_cycle_ok( $res, 'Response has no memory cycles' );
memory_cycle_ok( $stash, 'Stash has no memory cycles' );
memory_cycle_ok( $rs, 'Job RS has no memory cycles' );
memory_cycle_ok( $jobs, 'Job results have no memory cycles' );

done_testing;
