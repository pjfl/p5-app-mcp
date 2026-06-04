package App::MCP::Plugin::Nagios;

use App::MCP::Constants    qw( FALSE TRUE );
use File::DataClass::Types qw( Path Str );
use Class::Usul::Cmd::Util qw( includes );
use Sys::Hostname          qw( hostname );
use Moo;

with 'Web::Components::Role';
with 'App::MCP::Role::JSONParser';

=pod

=encoding utf-8

=head1 Name

App::MCP::Plugin::Nagios - Writes alert events to the Nagios log file

=head1 Synopsis

   use App::MCP::Plugin::Nagios;

=head1 Description

Writes alert events to the Nagios log file

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=item C<moniker>

Set default to C<nagios>

=cut

has '+moniker' => default => 'nagios';

=item C<filename>

String defaults to C<nagios.out>

=cut

has 'filename' => is => 'ro', isa => Str, default => 'nagios.out';

has '_outpath' =>
   is      => 'lazy',
   isa     => Path,
   default => sub {
      my $self = shift;

      return $self->config->tempdir->catfile($self->filename);
   };

=back

=head1 Subroutines/Methods

Defineds the following methods;

=over 3

=item C<post>

   $hash_ref = $self->post($payload);

=cut

sub post {
   my ($self, $payload) = @_;

   my $options  = $payload->{options} // { status => 'none' };
   my $is_error = $options->{status} eq 'error' ? TRUE : FALSE;

   return { message => 'Not an error', success => TRUE } unless $is_error;

   my $now     = time;
   my $command = 'PROCESS_SERVICE_CHECK_RESULT';
   my $host    = hostname;
   my $service = uc $self->config->prefix;
   my $message = $payload->{message};
   my $line    = "[${now}] ${command};${host};${service};1;${message}";

   $self->_outpath->appendln($line)->flush;

   return { message => 'All good bro!', success => TRUE };
}

use namespace::autoclean;

1;

__END__

=back

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Moo>

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

Copyright (c) 2026 Peter Flanigan. All rights reserved

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
