package App::MCP::ConfigEditor;

use namespace::autoclean;

use Moo;
use Class::Inspector;
use Class::Usul::Constants  qw( TRUE );
use Class::Usul::File;
use Class::Usul::Functions  qw( is_arrayref is_hashref is_member );
use Class::Usul::Response::Table;
use Class::Usul::Types      qw( ArrayRef BaseType NonEmptySimpleStr );

has 'excludes' => is => 'ro', isa => ArrayRef[NonEmptySimpleStr],
   builder     => sub { [ qw( BUILD BUILDALL BUILDARGS DEMOLISHALL
                              canonicalise does inflate_path inflate_paths
                              inflate_symbol meta new ) ] };

has 'usul'     => is => 'ro', isa => BaseType, handles => [ 'config', 'log' ],
   init_arg    => 'builder', required => TRUE;

# Private functions
my $_new_config_table = sub {
   my $values = shift;

   return Class::Usul::Response::Table->new( {
      class    => { default     => 'cell',
                    loaded      => 'cell', },
      count    => scalar @{ $values },
      fields   => [ qw( attr_name default loaded ) ],
      hclass   => { attr_name   => 'header minimal',
                    default     => 'header minimal',
                    loaded      => 'header most', },
      labels   => { attr_name   => 'Name',
                    default     => 'Default Value',
                    loaded      => 'Loaded Value', },
      values   => $values,
   } );
};

# Public methods
sub config_data {
   my $self = shift; my $loaded = {}; my $paths;

   $paths = $self->config->cfgfiles and $paths->[ 0 ]
      and $loaded = Class::Usul::File->data_load( paths => $paths ) || {};

   my $class = $self->usul->config_class;

   my $arrayrefs = []; my $hashrefs = []; my $scalars = [];

   for my $attr_name (grep { not is_member $_, $self->excludes }
                          @{ Class::Inspector->methods( $class, 'public' ) }) {
      my $default_value = $self->config->$attr_name;
      my $loaded_value  = $loaded->{ $attr_name };

      if (is_arrayref $default_value) {
         push @{ $arrayrefs }, {
            attr_name => $attr_name,
            default   => { type   => 'popupMenu',
                           values => $default_value,
                           widget => TRUE },
            loaded    => $loaded_value, };
      }
      elsif (is_hashref $default_value) {
         push @{ $hashrefs }, { attr_name => $attr_name,
                                default   => $default_value,
                                loaded    => $loaded_value, };
      }
      else {
         push @{ $scalars }, {
            attr_name => $attr_name,
            default   => $default_value,
            loaded    => { default => $loaded_value, widget => TRUE }, };
      }
   }

   return [ $_new_config_table->( $arrayrefs ),
            $_new_config_table->( $hashrefs ),
            $_new_config_table->( $scalars ) ];
}

1;

__END__

=pod

=encoding utf-8

=head1 Name

App::MCP::ConfigEditor - One-line description of the modules purpose

=head1 Synopsis

   use App::MCP::ConfigEditor;
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
