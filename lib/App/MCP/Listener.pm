# @(#)$Ident: Listener.pm 2013-11-05 01:58 pjf ;

package App::MCP::Listener;

use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.3.%d', q$Rev: 9 $ =~ /\d+/gmx );

use App::MCP;
use App::MCP::Request;
use Class::Usul;
use Class::Usul::File;
use Class::Usul::Functions  qw( find_apphome get_cfgfiles is_hashref );
use Class::Usul::Types      qw( BaseType NonZeroPositiveInt Object );
use JSON                    qw( );
use TryCatch;
use Web::Simple;

# Public attributes
has 'app'         => is => 'lazy', isa => Object, builder => sub {
   App::MCP->new( builder => $_[ 0 ]->_usul, port => $_[ 0 ]->port ) };

has 'port'        => is => 'lazy', isa => NonZeroPositiveInt, builder => sub {
   $ENV{MCP_LISTENER_PORT} || $_[ 0 ]->_usul->config->port };

# Private attributes
has '_transcoder' => is => 'lazy', isa => Object, builder => sub { JSON->new };

has '_usul'       => is => 'lazy', isa => BaseType, handles => [ 'log' ],
   builder        => sub {
      my $self  = shift;
      my $extns = [ keys %{ Class::Usul::File->extensions } ];
      my $attr  = { config       => { appclass => 'App::MCP',
                                      name     => 'listener' },
                    config_class => 'App::MCP::Config',
                    debug        => $ENV{MCP_DEBUG} || 0 };
      my $conf  = $attr->{config};

      $conf->{home    } = find_apphome $conf->{appclass},         undef, $extns;
      $conf->{cfgfiles} = get_cfgfiles $conf->{appclass}, $conf->{home}, $extns;

      return Class::Usul->new( $attr ) };

# Public methods
sub dispatch_request {
   sub (POST + /api/event/*) {
      return shift->_action( 'create_event', @_ );
   },
   sub (POST + /api/job/*) {
      return shift->_action( 'create_job', @_ );
   },
   sub (POST + /api/session/*) {
      return shift->_action( 'find_or_create_session', @_ );
   },
   sub {
      return shift->_encode_json( 405, 'Method not allowed' );
   };
}

# Private methods
sub _action {
   my ($self, $method, @args) = @_; my ($req, $res);

   try {
      $req = App::MCP::Request->new( $self->_usul, @args )->authenticate;
      $res = $self->_encode_json( $self->app->$method( $req ) );
   }
   catch ($e) {
      $self->log->error( $e ); return $self->_encode_json( $e->rv, "${e}" );
   }

   return $res;
}

sub _encode_json {
   my ($self, $code, $content) = @_;

   $content = $self->_transcoder->encode
      ( (is_hashref $content) ? $content : { message => $content } );

   return [ $code, [ 'Content-Type' => 'application/json' ], [ $content ] ];
}

1;

__END__

=pod

=head1 Name

App::MCP::Listener - <One-line description of module's purpose>

=head1 Version

This documents version v0.3.$Rev: 9 $

=head1 Synopsis

   use App::MCP::Listener;
   # Brief but working code examples

=head1 Description

=head1 Configuration and Environment

=head1 Subroutines/Methods

=head1 Diagnostics

=head1 Dependencies

=over 3

=item L<Class::Usul>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module.
Please report problems to the address below.
Patches are welcome

=head1 Acknowledgements

Larry Wall - For the Perl programming language

=head1 Author

Peter Flanigan, C<< <Support at RoxSoft dot co dot uk> >>

=head1 License and Copyright

Copyright (c) 2013 Peter Flanigan. All rights reserved

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
