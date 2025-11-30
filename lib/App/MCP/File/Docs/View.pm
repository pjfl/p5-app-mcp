package App::MCP::File::Docs::View;

use App::MCP::Markdown;
use HTML::Tiny;
use Pod::Markdown::Github;
use Moo;

has '_html' => is => 'ro', default => sub { HTML::Tiny->new };

sub get {
   my ($self, $path) = @_;

   my $parser = Pod::Markdown::Github->new;

   $parser->output_string(\my $markdown);
   $parser->parse_file($path->as_string);

   my $formatter = App::MCP::Markdown->new();

   return $formatter->markdown($markdown);
}

use namespace::autoclean;

1;
