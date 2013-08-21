# @(#)$Ident: Listener.pm 2013-06-24 12:31 pjf ;

package App::MCP::Listener;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.3.%d', q$Rev: 1 $ =~ /\d+/gmx );

use App::MCP::Schema;
use Web::Simple;

has 'appclass' => is => 'ro', required => 1;

has 'schema'   => is => 'lazy';

sub dispatch_request {
   sub (POST + /api/event + ?runid= + %*) {
      my ($code, $msg) = shift->schema->create_event( @_ );

      return [ $code, [ 'Content-type', 'text/plain' ], [ $msg ] ];
   },
   sub (GET) {
      [ 404, [ 'Content-type', 'text/plain' ], [ 'Not found' ] ]
   },
   sub {
      [ 405, [ 'Content-type', 'text/plain' ], [ 'Method not allowed' ] ]
   };
}

sub _build_schema {
   return App::MCP::Schema->new
      ( config  => { appclass => $_[ 0 ]->appclass, name => 'listener', },
        nodebug => 1, );
}

1;

__END__

=pod

=head1 Name

App::MCP::Listener - <One-line description of module's purpose>

=head1 Version

This documents version v0.3.$Rev: 1 $

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
