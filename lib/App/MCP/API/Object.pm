package App::MCP::API::Object;

use App::MCP::Constants     qw( EXCEPTION_CLASS FALSE TRUE );
use Class::Usul::Cmd::Types qw( Logger Str );
use Unexpected::Functions   qw( throw );
use DateTime::TimeZone;
use Try::Tiny;
use Moo;
use App::MCP::Attributes; # Will do namespace cleaning

has 'log' => is => 'ro', isa => Logger, required => TRUE;

has 'name' => is => 'ro', isa => Str, required => TRUE;

sub fetch : Auth('none') {
   my ($self, $context, @args) = @_;

   my $object;

   if ($self->name eq 'property') {
      my $request = $context->request;
      my $class   = $request->query_params->('class');
      my $prop    = $request->query_params->('property');
      my $value   = $request->query_params->('value', { raw => TRUE });

      $object = { found => \0 };

      if ($value) {
         try { # Defensively written
            my $r = $context->model($class)->find_by_key($value);

            $object->{found} = \1 if $r && $r->execute($prop);
         }
         catch { $self->log->error("${_}", $context) };
      }
   }
   else { throw 'Object [_1] unknown api attribute name', [$self->name] }

   $context->stash(json => $object);
   return;
}

sub get : Auth('view') {
   my ($self, $context, @args) = @_;

   my $object;

   if ($self->name eq 'timezones') {
      $object = { timezones => [DateTime::TimeZone->all_names] };
   }
   else { throw 'Object [_1] unknown api attribute name', [$self->name] }

   $context->stash(json => $object);
   return;
}

1;
