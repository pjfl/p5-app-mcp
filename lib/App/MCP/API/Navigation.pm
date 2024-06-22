package App::MCP::API::Navigation;

use App::MCP::Constants   qw( EXCEPTION_CLASS FALSE TRUE );
use Unexpected::Types     qw( Str );
use Unexpected::Functions qw( throw );
use Moo;
use App::MCP::Attributes; # Will do namespace cleaning

has 'name' => is => 'ro', isa => Str; # collect

sub messages : Auth('none') {
   my ($self, $context, @args) = @_;

   if ($self->name eq 'collect') {
      my $session  = $context->session;
      my $messages = $session->collect_status_messages($context->request);

      $context->stash(json => [ reverse @{$messages} ]);
   }
   else { throw 'Object [_1] unknown api attribute name', [$self->name] }

   return;
}

1;
