use t::boilerplate;

use Test::More;
use Test::Memory::Cycle;

use_ok 'App::MCP::Model::Job';

{ package TestApp;

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

my $env = {
   CONTENT_TYPE         => 'text/plain',
   HTTP_ACCEPT_LANGUAGE => 'en-gb,en;q=0.7,de;q=0.3',
   HTTP_HOST            => 'localhost:5000',
   PATH_INFO            => '/mcp/job',
   QUERY_STRING         => 'key=124-4',
   REMOTE_ADDR          => '127.0.0.1',
   REQUEST_METHOD       => 'GET',
   SERVER_PROTOCOL      => 'HTTP/1.1',
   'psgix.logger'       => sub { warn $_[0]->{message}."\n" },
   'psgix.session'      => { authenticated => 1 },
};
my $app   = TestApp->new({ appclass => 'App::MCP' });
my $req   = $app->new_from_simple_request({}, $env);
my $model = App::MCP::Model::Job->new(
   config        => $app->config,
   context_class => 'App::MCP::Context',
   log           => $app->log
);
my $context = $model->get_context({ request => $req });

$model->list($context);

my $table = $context->stash('table');

like $table->render, qr{ class="state-table" }mx, 'Render';

memory_cycle_ok( $req, 'Request has no memory cycles' );
memory_cycle_ok( $context, 'Context has no memory cycles' );
memory_cycle_ok( $table, 'Table has no memory cycles' );
memory_cycle_ok( $app, 'Application has no memory cycles' );

done_testing;
