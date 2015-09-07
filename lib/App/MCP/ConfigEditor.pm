package App::MCP::ConfigEditor;

use namespace::autoclean;

use Class::Usul::Constants qw( FALSE TRUE );
use Class::Usul::Functions qw( is_arrayref is_coderef is_hashref
                               list_attr_of throw );
use Class::Usul::Response::Table;
use Class::Usul::Types     qw( ArrayRef BaseType NonEmptySimpleStr );
use Pod::Xhtml;
use Moo;

has 'excludes' => is => 'ro', isa => ArrayRef[NonEmptySimpleStr],
   builder     => sub { [ qw( BUILD BUILDALL BUILDARGS DEMOLISHALL
                              canonicalise does inflate_path inflate_paths
                              inflate_symbol meta new ) ] };

has 'usul'     => is => 'ro', isa => BaseType, handles => [ 'config', 'log' ],
   init_arg    => 'builder', required => TRUE;

# Private functions
my $_new_attr_table = sub {
   my $rows = shift;

   return Class::Usul::Response::Table->new( {
      count  => scalar @{ $rows },
      fields => [ qw( attr_name value ) ],
      hclass => { attr_name => 'minimal',
                  value     => 'most', },
      labels => { attr_name => 'Name',
                  value     => 'Current Value', },
      values => $rows,
   } );
};

my $_get_anchor_text = sub {
   my $v = shift; $v =~ s{ [_] }{ }gmx; return ucfirst $v;
};

my $_get_value_widget; $_get_value_widget = sub {
   my $v = shift;

   is_arrayref $v and return {
      type => 'popupMenu', container => FALSE, values => $v, widget => TRUE, };

   is_coderef  $v and return $v->();

   is_hashref  $v or  return $v; 0 == (() = keys %{ $v }) and return '{}';

   my @rows = map   { { attr_name => $_,
                        value     => $_get_value_widget->( $v->{ $_ } ) } }
              keys %{ $v };

   return { type   => 'table',
            data   => $_new_attr_table->( \@rows ),
            widget => TRUE, };
};

my $_new_config_table = sub {
   my $rows = shift;

   return Class::Usul::Response::Table->new( {
      count  => scalar @{ $rows },
      fields => [ qw( attr_name class value ) ],
      hclass => { attr_name => 'minimal',
                  class     => 'minimal',
                  value     => 'most', },
      labels => { attr_name => 'Name',
                  class     => 'Defining Class',
                  value     => 'Current Value', },
      values => $rows,
   } );
};

my $_pod_to_html = sub {
   my ($parser, $pod) = @_; $pod = "=pod\n\n${pod}";

   open my $fh, '+<', \$pod or throw 'Cannot open from string reference';

   $parser->parse_from_filehandle( $fh ); close $fh;

   my $html = $parser->asString; $html =~ s{ [\n] }{}gmsx;

   return $html;
};

# Public methods
sub config_data {
   my $self = shift; my $rows = [];

   my $parser = Pod::Xhtml->new
      ( FragmentOnly => TRUE, MakeIndex => FALSE, StringMode => TRUE );

   for my $tuple (list_attr_of( $self->config, @{ $self->excludes } )) {
      push @{ $rows }, {
         attr_name    => {
            type      => 'anchor',
            container => FALSE,
            href      => '#',
            text      => $_get_anchor_text->( $tuple->[ 0 ] ),
            tip       => $_pod_to_html->( $parser, $tuple->[ 2 ] ),
            widget    => TRUE, },
         class        => $tuple->[ 1 ],
         value        => $_get_value_widget->( $tuple->[ 3 ] ) };
   }

   return $_new_config_table->( $rows );
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

Copyright (c) 2015 Peter Flanigan. All rights reserved

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
