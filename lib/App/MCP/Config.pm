# @(#)Ident: Config.pm 2013-05-26 22:34 pjf ;

package App::MCP::Config;

use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 5 $ =~ /\d+/gmx );

use Class::Usul::Moose;
use Class::Usul::Constants;
use Class::Usul::Functions       qw(fqdn);
use File::DataClass::Constraints qw(File);

extends qw(Class::Usul::Config::Programs);

has 'clock_tick_interval'  => is => 'ro',   isa => PositiveInt,
   default                 => 3;

has 'database'             => is => 'ro',   isa => NonEmptySimpleStr,
   default                 => 'schedule';

has 'identity_file'        => is => 'lazy', isa => File, coerce => TRUE,
   default                 => sub { [ $_[ 0 ]->my_home, qw(.ssh id_rsa) ] };

has 'max_ssh_worker_calls' => is => 'ro',   isa => PositiveOrZeroInt,
   default                 => 0;

has 'max_ssh_workers'      => is => 'ro',   isa => PositiveInt,
   default                 => 3;

has 'port'                 => is => 'ro',   isa => PositiveInt,
   default                 => 2012;

has 'schema_class'         => is => 'ro',   isa => NonEmptySimpleStr,
   default                 => 'App::MCP::Schema::Schedule';

has 'server'               => is => 'ro',   isa => NonEmptySimpleStr,
   default                 => 'Twiggy';

has 'servers'              => is => 'ro',   isa => ArrayRef,
   default                 => sub { [ fqdn ] };

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=encoding utf8

=head1 Name

App::MCP::Config - One-line description of the modules purpose

=head1 Synopsis

   use App::MCP::Config;
   # Brief but working code examples

=head1 Version

This documents version v0.1.$Rev: 5 $ of L<App::MCP::Config>

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

There are no known bugs in this module.
Please report problems to the address below.
Patches are welcome

=head1 Acknowledgements

Larry Wall - For the Perl programming language

=head1 Author

Peter Flanigan, C<< <pjfl@cpan.org> >>

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
