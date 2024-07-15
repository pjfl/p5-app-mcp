package App::MCP::Form::Configuration;

use Class::Usul::Cmd::Constants qw( DUMP_EXCEPT EXCEPTION_CLASS );
use HTML::Forms::Constants      qw( FALSE META TRUE );
use HTML::Forms::Types          qw( Str );
use Class::Usul::Cmd::Util      qw( list_attr_of list_methods_of );
use JSON::MaybeXS               qw( );
use Ref::Util                   qw( is_arrayref is_plain_hashref );
use Type::Utils                 qw( class_type );
use Text::MultiMarkdown;
use Moo;
use HTML::Forms::Moo;

extends 'HTML::Forms';
with    'HTML::Forms::Role::Defaults';

has '+info_message' => default => 'Current runtime configuration parameters';

has '_formatter' =>
   is      => 'lazy',
   isa     => class_type('Text::MultiMarkdown'),
   default => sub { Text::MultiMarkdown->new( tab_width => 3 ) };

has '_json' =>
   is      => 'ro',
   isa     => class_type(JSON::MaybeXS::JSON),
   default => sub {
      return JSON::MaybeXS->new( convert_blessed => TRUE );
   };

has '+title' => default => 'Configuration';

has_field 'configuration' =>
   type          => 'NonEditable',
   wrapper_class => 'input-immutable documentation';

after 'after_build_fields' => sub {
   my $self    = shift;
   my $config  = $self->context->config;
   my $methods = list_methods_of $config;
   my $attr    = [ list_attr_of $config, $methods, DUMP_EXCEPT ];
   my $content = join "\n", map {
      my $t = $_;
      my $s = "\n";

      for my $i (0 .. 3) {
         next if $i == 1;

         my $v = $t->[$i];

         $v = $self->_encode_ref($v) if is_plain_hashref $v or is_arrayref $v;
         $v = "# ${v}"    if $i == 0;
         $v = "\n${v}"    if $i == 2;
         $v = "\n   ${v}" if $i == 3;

         $s .= "${v}\n";
      }

      $s;
   } @{$attr};

   $self->field('configuration')->html($self->_formatter->markdown($content));
   return;
};

sub _encode_ref {
   my ($self, $v) = @_;

   (my $string = $self->_json->encode($v)) =~ s{ \n }{ }gmx;

   $string =~ s{ \{ }{\{ }gmx;
   $string =~ s{ \} }{ \}}gmx;
   $string =~ s{ \, }{\, }gmx;

   return $string;
}

use namespace::autoclean -except => META;

1;
