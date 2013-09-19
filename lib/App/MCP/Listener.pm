# @(#)$Ident: Listener.pm 2013-09-19 00:48 pjf ;

package App::MCP::Listener;

use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.3.%d', q$Rev: 3 $ =~ /\d+/gmx );

use App::MCP;
use Class::Usul;
use Class::Usul::File;
use Class::Usul::Functions  qw( find_apphome get_cfgfiles );
use Class::Usul::Types      qw( Object );
use Web::Simple;

has 'app'    => is => 'lazy', isa => Object,
   default   => sub { App::MCP->new( builder => $_[ 0 ] ) };

has 'usul'   => is => 'lazy', isa => Object, handles => [ qw( debug log ) ],
   init_arg  => undef;

sub config {
   return $_[ 0 ]->usul->config;
}

sub dispatch_request {
   sub (POST + /api/event + ?runid= + %*) {
      my ($code, $msg) = shift->app->create_event( @_ );

      return [ $code, [ 'Content-type', 'text/plain' ], [ $msg ] ];
   },
   sub (GET) {
      [ 404, [ 'Content-type', 'text/plain' ], [ 'Not found' ] ]
   },
   sub {
      [ 405, [ 'Content-type', 'text/plain' ], [ 'Method not allowed' ] ]
   };
}

sub _build_usul {
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
}

1;

__END__

=pod

=head1 Name

App::MCP::Listener - <One-line description of module's purpose>

=head1 Version

This documents version v0.3.$Rev: 3 $

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
