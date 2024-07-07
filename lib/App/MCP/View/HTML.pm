package App::MCP::View::HTML;

use HTML::Forms::Constants qw( TRUE );
use App::MCP::Util         qw( dt_from_epoch dt_human encode_for_html );
use Encode                 qw( encode );
use HTML::Entities         qw( encode_entities );
use HTML::Forms::Util      qw( get_token process_attrs );
use JSON::MaybeXS          qw( encode_json );
use Scalar::Util           qw( weaken );
use Moo;

with 'Web::Components::Role';
with 'Web::Components::Role::TT';

has '+moniker' => default => 'html';

sub serialize {
   my ($self, $context) = @_;

   $self->_maybe_render_partial($context);

   my $stash = $self->_add_tt_defaults($context);
   my $html  = encode($self->encoding, $self->render_template($stash));

   return [ $stash->{code}, _header($stash->{http_headers}), [$html] ];
}

sub _build__templater {
   my $self        =  shift;
   my $config      =  $self->config;
   my $args        =  {
      COMPILE_DIR  => $config->tempdir->catdir('ttc')->pathname,
      COMPILE_EXT  => 'c',
      ENCODING     => 'utf-8',
      INCLUDE_PATH => [$self->templates->pathname],
      PRE_PROCESS  => $config->skin . '/site/preprocess.tt',
      RELATIVE     => TRUE,
      TRIM         => TRUE,
      WRAPPER      => $config->skin . '/site/wrapper.tt',
   };
   # uncoverable branch true
   my $template    =  Template->new($args) or throw $Template::ERROR;

   return $template;
}

sub _add_tt_defaults {
   my ($self, $context) = @_; weaken $context;

   my $session = $context->session; weaken $session;
   my $tz      = $session->timezone;

   return {
      dt_from_epoch   => sub { dt_from_epoch shift, $tz },
      dt_human        => \&dt_human,
      dt_local        => sub { my $dt = shift; $dt->set_time_zone($tz); $dt },
      encode_entities => \&encode_entities,
      encode_for_html => \&encode_for_html,
      encode_json     => \&encode_json,
      process_attrs   => \&process_attrs,
      session         => $session,
      token           => sub { $context->verification_token },
      uri_for         => sub { $context->request->uri_for(@_) },
      uri_for_action  => sub { $context->uri_for_action(@_) },
      %{$context->stash},
   };
}

sub _header {
   return [ 'Content-Type'  => 'text/html', @{ $_[0] // [] } ];
}

sub _maybe_render_partial {
   my ($self, $context) = @_;

   my $header = $context->request->header('prefer') // q();

   return unless $header eq 'render=partial';

   my $page = $context->stash('page') // {};

   $page->{html} = 'none';
   $page->{wrapper} = 'none';
   $context->stash(page => $page);
   return;
}

1;

__END__

=pod

=encoding utf8

=head1 Name

App::MCP::View::HTML - One-line description of the modules purpose

=head1 Synopsis

   use App::MCP::View::HTML;
   # Brief but working code examples

=head1 Description

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=back

=head1 Subroutines/Methods

=head1 Diagnostics

=head1 Dependencies

=over 3

=item L<Class::Usul>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module. Please report problems to
http://rt.cpan.org/NoAuth/Bugs.html?Dist=App-MCP.
Patches are welcome

=head1 Acknowledgements

Larry Wall - For the Perl programming language

=head1 Author

Peter Flanigan, C<< <pjfl@cpan.org> >>

=head1 License and Copyright

Copyright (c) 2015 Peter Flanigan. All rights reserved

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
