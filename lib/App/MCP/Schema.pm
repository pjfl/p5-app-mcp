# @(#)$Ident: Schema.pm 2013-05-30 19:11 pjf ;

package App::MCP::Schema;

use version; our $VERSION = qv( sprintf '0.2.%d', q$Rev: 14 $ =~ /\d+/gmx );

use App::MCP::Functions     qw(trigger_input_handler);
use App::MCP::Schema::Authentication;
use App::MCP::Schema::Schedule;
use CatalystX::Usul::Constants;
use Class::Usul::Crypt      qw(decrypt);
use Class::Usul::Moose;
use Storable                qw(thaw);
use TryCatch;

extends q(CatalystX::Usul::Schema);

my ($schema_version)  = $VERSION =~ m{ (\d+\.\d+) }mx;

has '+database'       => default => q(schedule);

has '+schema_classes' => default => sub { {
   authentication     => q(App::MCP::Schema::Authentication),
   schedule           => q(App::MCP::Schema::Schedule), } };

has '+schema_version' => default => $schema_version;

has '_schedule'       => is => 'lazy', isa => 'Object', reader => 'schedule';

sub create_event {
   my ($self, $runid, $params) = @_; my $schema = $self->schedule;

   my $rs = $schema->resultset( 'ProcessedEvent' )
                   ->search( { runid => $runid }, { columns => [ 'token' ] } );

   my $event = $rs->first or return (404, 'Not found');

   $rs = $schema->resultset( 'Event' );

   try        { $rs->create( thaw decrypt $event->token, $params->{event} ) }
   catch ($e) { $self->log->error( $e ); return (400, $e) }

   trigger_input_handler $ENV{MCP_DAEMON_PID};
   return (204, NUL);
}

# Private methods
sub _build__schedule {
   my $self = shift; my $class = $self->schema_classes->{schedule};

   my $params = { quote_names => TRUE };

   return $class->connect( @{ $self->connect_info }, $params );
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=head1 Name

App::MCP::Schema - <One-line description of module's purpose>

=head1 Version

This documents version v0.2.$Rev: 14 $

=head1 Synopsis

   use App::MCP::Schema;
   # Brief but working code examples

=head1 Description

=head1 Configuration and Environment

=head1 Subroutines/Methods

=head2 create_event

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
