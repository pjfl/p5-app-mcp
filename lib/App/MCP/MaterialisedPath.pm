package App::MCP::MaterialisedPath;

use strictures;
use parent 'DBIx::Class::Helper::Row::OnColumnChange';

# Construction
use Class::C3::Componentised::ApplyHooks
   -before_apply => sub {
      $_[ 0 ]->can( 'materialised_path_columns' )
         or die 'Class ('.$_[0].') method materialised_path_columns not found';
   },
   -after_apply => sub {
      my %mat_paths = %{ $_[ 0 ]->materialised_path_columns };

      for my $path (keys %mat_paths) {
         $_[ 0 ]->_install_after_column_change( $mat_paths{ $path } );
         $_[ 0 ]->_install_full_path_rel( $mat_paths{ $path } );
         $_[ 0 ]->_install_reverse_full_path_rel( $mat_paths{ $path } );
      }
   };

# Public methods
sub insert {
   my $self = shift; my $ret = $self->next::method;

   my %mat_paths = %{ $ret->materialised_path_columns };

   for my $path (keys %mat_paths) {
      $ret->_set_materialised_path( $mat_paths{ $path } );
   }

   return $ret;
}

# Private methods
sub _install_after_column_change {
   my ($self, $path_info) = @_;

   my $method; $method = sub {
      my $self = shift; my $rel = $path_info->{children_relationship};

      $self->_set_materialised_path( $path_info );

      $method->( $_ ) for $self->$rel->search( { # to avoid recursion
         map +( "me.$_" => { '!=' => $self->get_column($_) }, ),
            $self->result_source->primary_columns
      } )->all
   };

   for my $column (map $path_info->{ $_ },
                   qw( parent_column materialised_path_column )) {
      $self->after_column_change( $column => {
         method => $method, txn_wrap => 1, } );
   }

   undef $method;
   return;
}

sub _install_full_path_rel {
   my ($self, $path_info) = @_;

   return $self->has_many( $path_info->{full_path} => $self, sub {
      my $args      = shift;
      my $separator = $path_info->{separator} || '/';
      my $fk        = $path_info->{parent_fk_column};
      my $mp        = $path_info->{materialised_path_column};
      my @me        = ( $path_info->{include_self_in_path}
                        ? { $args->{self_alias}.".${fk}" =>
                            { -ident => $args->{foreign_alias}.".${fk}" }, }
                        : () );
      my $concat    = __get_concat( $args->{self_resultsource} );
      my $like      = [ $args->{foreign_alias}.".${mp} ${concat} ?",
                        [ {} => "${separator}%" ] ];

      return
         ( [ { $args->{self_alias}.".${mp}" => { -like => \$like, } }, @me ],
           $args->{self_rowobj} && {
              $args->{foreign_alias}.".${fk}" => {
                 -in => [ grep   { $path_info->{include_self_in_path}
                                   || $_ ne $args->{self_rowobj}->$fk }
                          split m{ \Q$separator\E }msx,
                          $args->{self_rowobj}->get_column( $mp ) ],
              },
           } );
   } );
}

sub _install_reverse_full_path_rel {
   my ($self, $path_info) = @_;

   return $self->has_many( $path_info->{reverse_full_path} => $self, sub {
      my $args      = shift;
      my $separator = $path_info->{separator} || '/';
      my $fk        = $path_info->{parent_fk_column};
      my $mp        = $path_info->{materialised_path_column};
      my @me        = ( $path_info->{include_self_in_reverse_path}
                        ? { $args->{foreign_alias}.".${fk}" =>
                            { -ident => $args->{self_alias}.".${fk}" }, }
                        : () );
      my $concat    = __get_concat( $args->{self_resultsource} );
      my $like      = [ $args->{self_alias}.".${mp} ${concat} ?",
                        [ {} => "${separator}%" ] ];

      return [ {
         $args->{foreign_alias}.".${mp}" => { -like => \$like, } }, @me ];
   } );
}

sub _set_materialised_path {
   my ($self, $path_info) = @_;

   my $parent     = $path_info->{parent_column};
   my $parent_fk  = $path_info->{parent_fk_column};
   my $path       = $path_info->{materialised_path_column};
   my $parent_rel = $path_info->{parent_relationship};
   my $separator  = $path_info->{separator} || '/';

   $self->discard_changes; # XXX: Is this completely necesary?

   if ($self->get_column( $parent )) { # if we aren't the root
      $self->set_column( $path,
                         $self->$parent_rel->get_column( $path ) .
                         $separator .
                         $self->get_column( $parent_fk ) );
   }
   else { $self->set_column( $path, $self->$parent_fk ) }

   return $self->update;
}

# Private functions
{  my %concat_operators = ( 'DBIx::Class::Storage::DBI::MSSQL' => '+', );

   sub __get_concat {
      for (keys %concat_operators) {
         $_[ 0 ]->storage->isa( $_ ) and return $concat_operators{ $_ };
      }

      return '||';
   }
}

1;

__END__

=pod

=head1 Name

App::MCP::MaterialisedPath - <One-line description of module's purpose>

=head1 Synopsis

   use App::MCP::MaterialisedPath;
   # Brief but working code examples

=head1 Description

Robbed from L<DBIx::Class::MaterializedPath>. This implementation works with
Perl 5.10

=head1 Configuration and Environment

=head1 Subroutines/Methods

=head2 insert

=head1 Diagnostics

=head1 Dependencies

=over 3

=item L<DBIx::Class::Helper::Row::OnColumnChange>

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

Copyright (c) 2024 Peter Flanigan. All rights reserved

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
