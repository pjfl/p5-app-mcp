# @(#)$Ident: Listener.pm 2013-10-04 16:03 pjf ;

package App::MCP::Listener;

use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.3.%d', q$Rev: 5 $ =~ /\d+/gmx );

use App::MCP;
use Class::Usul;
use Class::Usul::File;
use Class::Usul::Functions  qw( find_apphome get_cfgfiles );
use Class::Usul::Types      qw( BaseType NonZeroPositiveInt Object );
use Web::Simple;

has 'app'    => is => 'lazy', isa => Object, builder => sub {
   App::MCP->new( builder => $_[ 0 ]->_usul, port => $_[ 0 ]->port ) };

has 'port'   => is => 'lazy', isa => NonZeroPositiveInt,
   builder   => sub { $ENV{MCP_LISTENER_PORT} || $_[ 0 ]->_usul->config->port };

has '_usul'  => is => 'lazy', isa => BaseType, builder => sub {
   my $self  = shift;
   my $extns = [ keys %{ Class::Usul::File->extensions } ];
   my $attr  = { config       => { appclass => 'App::MCP',
                                   name     => 'listener' },
                 config_class => 'App::MCP::Config',
                 debug        => $ENV{MCP_DEBUG} || 0 };
   my $conf  = $attr->{config};

   $conf->{home    } = find_apphome $conf->{appclass},         undef, $extns;
   $conf->{cfgfiles} = get_cfgfiles $conf->{appclass}, $conf->{home}, $extns;

   return Class::Usul->new( $attr );
};

sub dispatch_request {
   sub (POST + /api/event + ?runid= + %*) {
      my ($code, $msg) = shift->app->create_event( @_ );

      return [ $code, [ 'Content-type', 'text/plain' ], [ $msg ] ];
   },
   sub (POST + /api/job + %*) {
      my ($code, $msg) = shift->app->create_job( @_ );

      return [ $code, [ 'Content-type', 'text/plain' ], [ $msg ] ];
   },
   sub (GET) {
      [ 404, [ 'Content-type', 'text/plain' ], [ 'Not found' ] ]
   },
   sub {
      [ 405, [ 'Content-type', 'text/plain' ], [ 'Method not allowed' ] ]
   };
}

1;

__END__

=pod

=head1 Name

App::MCP::Listener - <One-line description of module's purpose>

=head1 Version

This documents version v0.3.$Rev: 5 $

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
