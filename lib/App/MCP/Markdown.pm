package App::MCP::Markdown;

use strictures;
use parent 'Text::MultiMarkdown';

sub _DoCodeBlocks { # Add support for triple graves
   my ($self, $text) = @_;

   $text =~ s{
         (?:```(.*)[ \n])
         ((?: .*\n+)+)
         (?:^```(.*)[ \n])
      }{
      my $class = $1 || $3 || q();
      my $codeblock = $2;
      my $result;

      $codeblock = $self->_EncodeCode($self->_Outdent($codeblock));
      $codeblock = $self->_Detab($codeblock);
      $codeblock =~ s/\A\n+//;
      $codeblock =~ s/\n+\z//;
      $codeblock = $self->_H12Hash($codeblock);
      $class     = " class=\"${class}\"" if $class;
      $result    = "\n\n<pre><code${class}>${codeblock}\n</code></pre>\n\n";
      $result;
   }egmx;

   return $text;
}

sub _H12Hash {
   my ($self, $block) = @_;

   $block =~ s{ &lt; h1 [^\&]* &gt; }{\n# }mx;
   $block =~ s{ &lt; /h1 &gt; }{}mx;

   return $block;
}

1;
