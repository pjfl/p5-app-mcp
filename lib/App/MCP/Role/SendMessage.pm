package App::MCP::Role::SendMessage;

use App::MCP::Constants qw( FALSE TRUE );
use Moo::Role;

with 'App::MCP::Role::Redis';

sub send_message {
   my ($self, $context, $token, $payload) = @_;

   $self->redis_client->set_with_ttl("send_message-${token}", $payload, 1800);

   my $prefix  = $context->config->prefix;
   my $program = $context->config->bin->catfile("${prefix}-cli");
   my $command = "${program} -o token=${token} send_message email";
   my $name    = 'send_message' . substr $token, 24, 8;
   my $options = {
      command      => $command,
      delete_after => TRUE,
      group_id     => $context->session->{role_id},
      host         => 'localhost',
      job_name     => $name,
      owner_id     => $context->session->{user_id},
      type         => 'job',
      user_name    => $prefix,
   };

   return $context->model('Job')->create($options);
}

use namespace::autoclean;

1;
