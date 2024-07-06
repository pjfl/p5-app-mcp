package App::MCP::Form::Changes;

use HTML::Forms::Constants qw( EXCEPTION_CLASS FALSE META TRUE );
use HTML::Forms::Types     qw( Str );
use Type::Utils            qw( class_type );
use Text::MultiMarkdown;
use Moo;
use HTML::Forms::Moo;

extends 'HTML::Forms';
with    'HTML::Forms::Role::Defaults';

has 'formatter' =>
   is      => 'lazy',
   isa     => class_type('Text::MultiMarkdown'),
   default => sub { Text::MultiMarkdown->new( tab_width => 3 ) };

has '+title' => default => 'Changes';

has_field 'changes' => type => 'NonEditable';

after 'after_build_fields' => sub {
   my $self   = shift;
   my $config = $self->context->config;
   my $path   = $config->home->catfile('Changes');

   $path = $config->config_home->catfile('Changes') unless $path->exists;

   my $content = join "\n", map { "    ${_}" } $path->getlines;

   $self->field('changes')->html($self->formatter->markdown($content));
   return;
};

use namespace::autoclean -except => META;

1;
