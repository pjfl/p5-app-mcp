package App::MCP::Form::Changes;

use HTML::Forms::Constants qw( EXCEPTION_CLASS FALSE META TRUE );
use HTML::Forms::Types     qw( Str );
use Type::Utils            qw( class_type );
use App::MCP::Markdown;
use Moo;
use HTML::Forms::Moo;

extends 'HTML::Forms';
with    'HTML::Forms::Role::Defaults';

has 'formatter' =>
   is      => 'lazy',
   isa     => class_type('App::MCP::Markdown'),
   default => sub { App::MCP::Markdown->new( tab_width => 3 ) };

has '+title' => default => 'Changes';

has_field 'changes' => type => 'NonEditable';

after 'after_build_fields' => sub {
   my $self   = shift;
   my $config = $self->context->config;
   my $path   = $config->home->catfile('Changes');

   $path = $config->config_home->catfile('Changes') unless $path->exists;

   my $content = join "\n", map { $_ =~ s{ \A ([ ]*)? \- }{}mx; $_ } map {
      $_ =~ m{ \A \S+ }mx ? $_ !~ m{ \A \d }mx ? "### ${_}" : "#### ${_}" : $_
   } $path->getlines;

   $self->field('changes')->html($self->formatter->markdown($content));
   return;
};

use namespace::autoclean -except => META;

1;
