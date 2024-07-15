package App::MCP::File::Docs::View;

use HTML::Tiny;
use Pod::Markdown::Github;
use App::MCP::Markdown;
use Moo;

has '_html' => is => 'ro', default => sub { HTML::Tiny->new };

sub get {
   my ($self, $path) = @_;

   my $parser    = Pod::Markdown::Github->new;
   my $formatter = App::MCP::Markdown->new();

   $parser->output_string(\my $markdown);
   $parser->parse_file($path->as_string);

   my $doc = $formatter->markdown($markdown);

   return $self->_html->div({ class => 'documentation' }, $doc);
}

1;
