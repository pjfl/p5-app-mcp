package App::MCP::Markdown;

use URI::Escape qw( uri_escape uri_unescape );
use Moo;

extends 'Text::MultiMarkdown';

=pod

=encoding utf-8

=head1 Name

App::MCP::Markdown - Markdown formatter

=head1 Synopsis

   use App::MCP::Markdown;

   my $formatter = App::MCP::Markdown->new( tab_width => 3 );

=head1 Description

Markdown formatter. A subclass of L<Text::MultiMarkdown> which adds support
for code blocks introduced by three grave characters followed by the
language name

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=item C<local_docs>

When generating links make them refer to local documentation for this list
of packages

=cut

has 'local_docs' =>
   is      => 'ro',
   default => sub {
      return [
         qw(App::Burp App::Job Class::Usul::Cmd HTML::Forms HTML::StateTable
            App::MCP Web::Components Web::ComposableRequest)
      ];
   };

=item C<remote_pattern>

The default URI pattern to match against

=cut

has 'remote_pattern' => is => 'ro', default => 'https://metacpan\.org/pod/';

=back

=head1 Subroutines/Methods

Defines the following methods;

=over 3

=item C<localise_markdown>

   $markdown = $self->localise_markdown($context, $markdown);

Replace default links with ones that point to local documentation

=cut

sub localise_markdown {
   my ($self, $context, $markdown) = @_;

   #   $markdown =~ s{ \\ }{}gmx;
   $markdown =~ s{ \\(\[) }{$1}gmx;
   $markdown =~ s{ \\(\]) }{$1}gmx;
   $markdown =~ s{ ([\` ])_(\w+) }{$1$2}gmx;

   return '<h1>Nothing Found</h1>' unless length $markdown > 2;

   for my $package (@{$self->local_docs}) {
      my $remote = $self->remote_pattern . uri_escape($package);

      $markdown =~ s{ \(($remote[^\)]*)\) }{_substitute($self,$context,$1)}gemx;
   }

   return $markdown;
}

# Private methods
sub _DoCodeBlocks { # Add support for triple graves
   my ($self, $text) = @_;

   $text =~ s{
         (?:```(.*)[ \n])
         ([^`]+)
         (?:[ \n]?```([^ \n]*)?)
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

sub _substitute {
   my ($self, $context, $remote) = @_;

   my $pattern = $self->remote_pattern;

   return "(${remote})" unless $remote =~ m{ $pattern }mx;

   $remote =~ s{ $pattern }{}mx;

   my @parts    = split m{ :: }mx, uri_unescape($remote);
   my $selected = pop @parts;
   my $dir      = join '!', @parts;
   my $query    = { directory => $dir, selected => "${selected}.pm" };
   my $actionp  = (!$dir || $dir =~ m{ \A App }mx)
                ? 'doc/application' : 'doc/server';
   my $uri      = $context->uri_for_action($actionp, [], $query);

   return "(${uri})";
}

use namespace::autoclean;

1;

__END__

=back

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Text::MultiMarkdown>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module. Please report problems to
http://rt.cpan.org/NoAuth/Bugs.html?Dist=App::MCP.
Patches are welcome

=head1 Acknowledgements

Larry Wall - For the Perl programming language

=head1 Author

Peter Flanigan, C<< <pjfl@cpan.org> >>

=head1 License and Copyright

Copyright (c) 2025 Peter Flanigan. All rights reserved

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See L<perlartistic>

This program is distributed in the hope that it will be useful,
but WITHOUT WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE

=cut

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
