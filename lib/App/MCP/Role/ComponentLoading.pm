package App::MCP::Role::ComponentLoading;

use namespace::autoclean;

use App::MCP::Functions    qw( load_components );
use Class::Usul::Functions qw( exception is_arrayref throw );
use Class::Usul::Types     qw( ArrayRef Bool HashRef LoadableClass
                               NonEmptySimpleStr Object );
use HTTP::Status           qw( HTTP_BAD_REQUEST HTTP_FOUND
                               HTTP_INTERNAL_SERVER_ERROR );
use Try::Tiny;
use Moo::Role;

requires qw( usul );

has 'controllers'   => is => 'lazy', isa => ArrayRef[Object], builder => sub {
   my $controllers  =
      load_components  $_[ 0 ]->usul->config->appclass.'::Controller',
         { builder  => $_[ 0 ]->usul, models => $_[ 0 ]->models, };
   return [ map { $controllers->{ $_ } } sort keys %{ $controllers } ] };

has 'models'        => is => 'lazy', isa => HashRef[Object], builder => sub {
   load_components     $_[ 0 ]->usul->config->appclass.'::Model',
      { builder     => $_[ 0 ]->usul, views => $_[ 0 ]->views, } };

has 'request_class' => is => 'lazy', isa => LoadableClass,
   builder          => sub { $_[ 0 ]->usul->config->request_class };

has 'views'         => is => 'lazy', isa => HashRef[Object], builder => sub {
   load_components     $_[ 0 ]->usul->config->appclass.'::View',
      { builder     => $_[ 0 ]->usul, } };

# Public methods
sub render {
   my ($self, $args) = @_; my $models = $self->models;

   (is_arrayref $args and $args->[ 0 ] and exists $models->{ $args->[ 0 ] })
      or return $args;

   my ($model, $method, undef, @args) = @{ $args }; my ($req, $res);

   try   { $req = $self->request_class->new( $self->usul, $model, @args ) }
   catch { $res = __internal_server_error( $_ ) };

   $res and return $res;

   try {
      $method eq 'from_request' and $method = $req->tunnel_method.'_action';

      my $stash = $models->{ $model }->execute( $method, $req );

      if (exists $stash->{redirect}) { $res = $self->_redirect( $req, $stash ) }
      else { $res = $self->_render_view( $model, $method, $req, $stash ) }
   }
   catch { $res = $self->_render_exception( $model, $req, $_ ) };

   $req->session->update;

   return $res;
}

# Private methods
sub _redirect {
   my ($self, $req, $stash) = @_; my $code = $stash->{code} || HTTP_FOUND;

   my $redirect = $stash->{redirect}; my $message = $redirect->{message};

   if ($message) {
      my $mid = $req->session->status_message( $message );

      $self->log->info( $req->loc_default( @{ $message } ) );
      $redirect->{location}->query_form( 'mid', $mid );
   }

   return [ $code, [ 'Location', $redirect->{location} ], [] ];
}

sub _render_view {
   my ($self, $model, $method, $req, $stash) = @_;

   $stash->{view} or throw error => 'Model [_1] method [_2] stashed no view',
                            args => [ $model, $method ];

   my $view = $self->views->{ $stash->{view} }
      or throw error => 'Model [_1] method [_2] unknown view [_3]',
                args => [ $model, $method, $stash->{view} ];
   my $res  = $view->serialize( $req, $stash )
      or throw error => 'View [_1] returned false', args => [ $stash->{view} ];

   return $res
}

sub _render_exception {
   my ($self, $model, $req, $e) = @_; my $res; my $username = $req->username;

   my $msg = "${e}"; chomp $msg; $self->log->error( "${msg} (${username})" );

   ($e->can( 'rv' ) and $e->rv > HTTP_BAD_REQUEST)
      or $e = exception $e, { rv => HTTP_BAD_REQUEST };

   try {
      my $stash = $self->models->{ $model }->exception_handler( $req, $e );

      $res = $self->_render_view( $model, 'exception_handler', $req, $stash );
   }
   catch { $res = __internal_server_error( $e, $_ ) };

   return $res;
}

# Private functions
sub __internal_server_error {
   my ($e, $secondary_error) = @_; my $message = "${e}\r\n";

   $secondary_error and $secondary_error ne "${e}"
      and $message .= "Secondary error: ${secondary_error}";

   return [ HTTP_INTERNAL_SERVER_ERROR, __plain_header(), [ $message ] ];
}

sub __plain_header {
   return [ 'Content-Type', 'text/plain' ];
}

1;

__END__

=pod

=encoding utf-8

=head1 Name

App::MCP::Role::ComponentLoading - One-line description of the modules purpose

=head1 Synopsis

   use App::MCP::Role::ComponentLoading;
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

Copyright (c) 2014 Peter Flanigan. All rights reserved

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
