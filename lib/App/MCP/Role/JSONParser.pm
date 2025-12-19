package App::MCP::Role::JSONParser;

use Class::Usul::Cmd::Constants qw( FALSE NUL SPC TRUE );
use Class::Usul::Cmd::Util      qw( squeeze );
use Type::Utils                 qw( class_type );
use JSON::MaybeXS               qw( );
use Moo::Role;

has 'json_parser' =>
   is      => 'lazy',
   isa     => class_type(JSON::MaybeXS::JSON),
   default => sub { JSON::MaybeXS->new( convert_blessed => TRUE ) };

sub json_pretty_print {
   my ($self, $v) = @_;

   # The output from this is not pretty enough. So regex time...
   my $string   = $self->json_parser->pretty->relaxed->canonical->encode($v);
   my $in_array = FALSE;
   my $buffer   = NUL;
   my $indent   = NUL;
   my $level    = 1;
   my $lines    = NUL;

   for my $line (split m{ \n }mx, $string) {
      $line     = squeeze $line;
      $level-- if $line =~ m{ [\}\]] }mx;
      $indent   = SPC x ($level * 3);
      $in_array = TRUE  if $line =~ m{ \[ }mx;
      $in_array = FALSE if $line =~ m{ \] }mx;

      if ($in_array) {
         $buffer .= "\n" if $line =~ m{ [\[\{] }mx;
         $buffer .= "${indent}${line}";
      }
      else {
         $lines .= "${buffer}" if $buffer;
         $lines .= "\n" if $line =~ m{ [ ]*\] }mx && $lines =~ m{ \}[ ]* \z }mx;
         $lines .= "${indent}${line}\n";
         $buffer = NUL;
      }

      $level++ if $line =~ m{ [\{\[] }mx;
   }

   $lines =~ s{ \n\n }{\n}gmx;
   $lines =~ s{ ([^ \n]+) [ ]+ \] }{$1 \]}gmx;
   $lines =~ s{ \[ [ ]+ }{\[ }gmx;
   $lines =~ s{ \{ [ ]+ }{\{ }gmx;
   $lines =~ s{ \" [ ]+ \} }{\" \}}gmx;
   $lines =~ s{ ,  [ ]+ }{, }gmx;

   return $lines;
}

use namespace::autoclean;

1;
