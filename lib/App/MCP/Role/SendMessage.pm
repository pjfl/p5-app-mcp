package App::MCP::Role::SendMessage;

use App::MCP::Constants qw( TRUE );
use Moo::Role;

with 'App::MCP::Role::JSONParser';
with 'App::MCP::Role::Redis';

has '+redis_client_name' => is => 'ro', default => 'job_stash';

sub send_message {
   my ($self, $context, $token, $params) = @_;

   $self->redis->set($token, $self->json_parser->encode($params));

   my $prefix  = $context->config->prefix;
   my $program = $context->config->bin->catfile("${prefix}-cli");
   my $command = "${program} -o token=${token} send_message email";
   my $name    = 'send_message' . substr $token, 24, 8;
   my $args    = {
      command      => $command,
      delete_after => TRUE,
      group_id     => $context->session->{role_id},
      host         => 'localhost',
      job_name     => $name,
      owner_id     => $context->session->{user_id},
      type         => 'job',
      user_name    => $prefix,
   };

   return $context->model('Job')->create($args);
}

use namespace::autoclean;

1;
