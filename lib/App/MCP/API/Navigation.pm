package App::MCP::API::Navigation;

use App::MCP::Constants   qw( EXCEPTION_CLASS FALSE TRUE );
use Unexpected::Types     qw( Str );
use Unexpected::Functions qw( throw );
use Moo;
use App::MCP::Attributes; # Will do namespace cleaning

has 'name' => is => 'ro', isa => Str; # collect

sub messages : Auth('none') {
   my ($self, $context, @args) = @_;

   my $result;

   if ($self->name eq 'collect') {
      my $session  = $context->session;
      my $messages = $session->collect_status_messages($context->request);

      $result = [ reverse @{$messages} ];
   }
   else { throw 'Object [_1] unknown api attribute name', [$self->name] }

   $context->stash(json => $result);
   return;
}

1;
