package App::MCP::Form::Configuration;

use Class::Usul::Cmd::Constants qw( DUMP_EXCEPT EXCEPTION_CLASS );
use HTML::Forms::Constants      qw( FALSE META TRUE );
use HTML::Entities              qw( encode_entities );
use Class::Usul::Cmd::Util      qw( list_attr_of list_methods_of );
use Ref::Util                   qw( is_arrayref is_plain_hashref );
use Type::Utils                 qw( class_type );
use HTML::Forms::Util           qw( data2markup );
use App::MCP::Markdown;
use Pod::Markdown::Github;
use Moo;
use HTML::Forms::Moo;

extends 'HTML::Forms';
with    'HTML::Forms::Role::Defaults';

has '+info_message' => default => 'Current runtime configuration parameters';
has '+title'        => default => 'Configuration';

has '_formatter' =>
   is      => 'lazy',
   isa     => class_type('App::MCP::Markdown'),
   default => sub { App::MCP::Markdown->new };

has_field 'configuration' =>
   type          => 'NonEditable',
   wrapper_class => 'input-immutable documentation';

after 'after_build_fields' => sub {
   my $self    = shift;
   my $config  = $self->context->config;
   my $methods = list_methods_of $config;
   my $attr    = [ list_attr_of $config, $methods, DUMP_EXCEPT ];
   my $is_ref  = sub { is_plain_hashref($_[0]) || is_arrayref($_[0]) };
   my $content = join "\n", map {
      my $t = $_;
      my $s = "\n";

      for my $i (0 .. 3) {
         next if $i == 1;

         my $v = $t->[$i];

         if    ($i == 0) { $v = "## <span id=\"${v}\">${v}</span>\n\n" }
         elsif ($i == 2) { $v = $self->_pod2markdown($v) }
         elsif ($i == 3) {
            if ($is_ref->($v)) { $v = '<div>' . data2markup($v) . '</div>' }
            else { $v = "```value\n${v} \n```" }
         }

         $s .= $v;
      }

      $s;
   } @{$attr};

   $self->field('configuration')->html($self->_formatter->markdown($content));
   return;
};

sub _pod2markdown {
   my ($self, $pod) = @_;

   my $parser = Pod::Markdown::Github->new;

   $parser->output_string(\my $markdown);
   $parser->parse_string_document("=pod\n\n${pod}\n\n=cut\n");

   return $markdown;
}

use namespace::autoclean -except => META;

1;
