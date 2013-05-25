# @(#)Ident: Periodical.pm 2013-05-25 12:11 pjf ;

package App::MCP::Async::Periodical;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 3 $ =~ /\d+/gmx );

use Class::Usul::Constants;
use Class::Usul::Functions qw(arg_list pad);
use Scalar::Util           qw(blessed);

sub new {
   my $self = shift; my $attr = arg_list( @_ );

   my $factory = delete $attr->{factory};

   $attr->{id  } = $factory->uuid;
   $attr->{log } = $factory->builder->log;
   $attr->{loop} = $factory->loop;

   my $new = bless $attr, blessed $self || $self;

   $new->{autostart} and $new->start;

   return $new;
}

sub pid {
   return $_[ 0 ]->{id};
}

sub start {
   my $self = shift;

   $self->{loop}->start_timer( $self->{id}, $self->{code}, $self->{interval} );

   return;
}

sub stop {
   my $self = shift;
   my $desc = $self->{description};
   my $key  = $self->{log_key};
   my $id   = $self->{id};
   my $did  = pad $id, 5, 0, 'left';

   $self->{log}->info( "${key}[${did}]: Stopping ${desc}" );
   $self->{loop}->stop_timer( $id );
   return;
}

1;

__END__

=pod

=encoding utf8

=head1 Name

App::MCP::Async::Periodical - One-line description of the modules purpose

=head1 Synopsis

   use App::MCP::Async::Periodical;
   # Brief but working code examples

=head1 Version

This documents version v0.1.$Rev: 3 $ of L<App::MCP::Async::Periodical>

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
