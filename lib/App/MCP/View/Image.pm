package App::MCP::View::Image;

use HTML::Forms::Constants qw( NUL );
use MIME::Types;
use Moo;

with 'Web::Components::Role';

has '+moniker' => default => 'image';

has 'default_image_file' => is => 'lazy', default => 'thumb.svg';

has 'default_mime_type' => is => 'lazy', default => 'image/svg+xml';

has 'mime_types' => is => 'lazy', default => sub { MIME::Types->new };

sub serialize {
   my ($self, $context) = @_;

   my $stash = $context->stash;

   $stash->{mime_type} //= $self->_mime_type($stash->{content_path});

   my $body = $stash->{body} // $self->_body($stash);

   return [ $stash->{code}, $self->_header($stash), [$body] ];
}

sub _body {
   my ($self, $stash) = @_;

   if ($stash->{thumbnail}) {
      unless ($stash->{mime_type} && $stash->{mime_type} =~ m{ \A image/ }mx) {
         my $imagedir = $self->config->rootdir->catdir('img');

         $stash->{content_path} = $imagedir->catfile($self->default_image_file);
         $stash->{mime_type} = $self->default_mime_type;
      }
   }

   my $path = $stash->{content_path};

   return $path ? $path->slurp : NUL;
}

sub _header {
   my ($self, $stash) = @_;

   my $type = $stash->{mime_type};

   return [ 'Content-Type' => $type, @{$stash->{http_headers} // []} ];
}

sub _mime_type {
   my ($self, $path) = @_;

   return $self->default_mime_type unless $path;

   return $self->mime_types->mimeTypeOf($path->suffix);
}

use namespace::autoclean;

1;
