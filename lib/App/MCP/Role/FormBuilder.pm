package App::MCP::Role::FormBuilder;

use App::MCP::Attributes;  # Will clean namespace
use App::MCP::Constants    qw( DOTS FALSE HASH_CHAR NUL TRUE );
use App::MCP::Form;
use Class::Usul::Functions qw( ensure_class_loaded first_char pad );
use Class::Usul::Response::Table;
use Data::Validation;
use File::Gettext::Schema;
use HTTP::Status           qw( HTTP_OK );
use Scalar::Util           qw( blessed );
use Try::Tiny;
use Moo::Role;

requires qw( config debug get_stash log schema_class usul );

# Private functions
my $_new_grid_table = sub {
   my ($label, $values) = @_;

   return Class::Usul::Response::Table->new( {
      class    => { item     => 'grid_cell',
                    item_num => 'grid_cell lineNumber first', },
      count    => scalar @{ $values },
      fields   => [ qw( item_num item ) ],
      hclass   => { item     => 'grid_header most',
                    item_num => 'grid_header minimal first', },
      labels   => { item     => $label || 'Select Item',
                    item_num => HASH_CHAR, },
      typelist => { item_num => 'numeric', },
      values   => $values,
   } );
};

# Private methods
my $_check_field = sub {
   my ($self, $req) = @_; my $params = $req->query_params;

   my $domain = $params->( 'domain' );
   my $form   = $params->( 'form'   );
   my $id     = $params->( 'id'     );
   my $val    = $params->( 'val', { raw => TRUE } );
   my $config = App::MCP::Form->load_config
      ( $self->usul, $domain, $req->locale );
   my $meta   = $config->{ $form }->{meta};
   my $class  = $self->schema_class.'::Result::'.$meta->{result_class};

   ensure_class_loaded( $class );

   my $attr   = $class->validation_attributes; $attr->{level} = 4;

   return Data::Validation->new( $attr )->check_field( $id, $val );
};

my $_new_grid_row = sub {
   my ($self, $req, $args, $rowid, $row) = @_;

   my $form     = $args->{form};
   my $method   = $args->{method};
   my $link_num = $args->{link_num};
   my $params   = $req->query_params;
   my $id       = $params->( 'id' );
   my $button   = $params->( 'button', { optional => TRUE } ) // NUL;
  (my $field    = $id) =~ s{ _grid \z }{}msx;
      $field    = (split m{ _ }mx, $field)[ 1 ];
   my $item     = $self->$method( $req, $args->{link_num}, $row );
   my $rv       = (delete $item->{value}) || $item->{text};
   my $iargs    = "[ '${form}', '${field}', '${rv}', '${button}' ]";

   $item->{class    } //= 'chooser_grid fade submit';
   $item->{config   }   = { args => $iargs, method => "'returnValue'", };
   $item->{container}   = FALSE;
   $item->{id       }   = "${id}_link${link_num}";
   $item->{type     }   = 'anchor';
   $item->{widget   }   = TRUE;

   return {
      class   => 'grid',
      classes => { item     => 'grid_cell',
                   item_num => 'grid_cell lineNumber first' },
      fields  => [ qw( item_num item ) ],
      id      => $rowid,
      type    => 'tableRow',
      values  => { item => $item, item_num => $link_num + 1, }, };
};

my $_set_column = sub {
   my ($self, $args, $rec, $col) = @_;

   my $prefix = $args->{method};
   my $method = $prefix ? "${prefix}${col}" : undef;
   my $value  = $method && $self->can( $method )
              ? $self->$method( $args->{params} )
              : $args->{params}->( $col, { optional => TRUE, raw => TRUE } );

   defined $value or return;

   if (blessed $rec) { $rec->$col( "${value}" ) }
   else { $rec->{ $col } = "${value}" }

   return;
};

# Construction
around 'get_stash' => sub {
   my ($orig, $self, $req, $page, $form_name, $row) = @_;

   $form_name or return $orig->( $self, $req, $page );

   my $form = App::MCP::Form->new( $self, $req, $form_name, $row );

   $page->{first_field} = $form->first_field;

   my $stash = $orig->( $self, $req, $page );

   $stash->{form} = $form; $stash->{template} //= $form->template;

   return $stash;
};

# Public methods
sub build_chooser {
   my ($self, $req) = @_; my $params = $req->query_params;

   my $form   = $params->( 'form'  );
   my $field  = $params->( 'field' );
   my $button = $params->( 'button', { optional => TRUE } ) // NUL;
   my $event  = $params->( 'event',  { optional => TRUE } ) // 'load';
   my $val    = $params->( 'val',    { optional => TRUE } ) // NUL;
   my $toggle = $params->( 'toggle', { optional => TRUE } ) ? 'true' : 'false';
   my $show   = "function() { this.window.dialogs[ '${field}' ].show() }";
   my $id     = "${form}_${field}";

   $val =~ s{ [\*] }{%}gmx;

   return {
      'meta'    => { id => $params->( 'id' ) },
      $id       => {
         id     => $id,
         config => { button     => "'${button}'",
                     event      => "'${event}'",
                     fieldValue => "'${val}'",
                     gridToggle => $toggle,
                     onComplete => $show }, } };
}

sub build_grid_rows {
   my ($self, $req, $args) = @_; my $params = $req->query_params;

   my $id        = $params->( 'id'        );
   my $page      = $params->( 'page'      ) || 0;
   my $page_size = $params->( 'page_size' ) || 10;
   my $start     = $page * $page_size;
   my $rows      = {};
   my $count     = 0;

   for my $row (@{ $args->{values} }) {
      $args->{link_num} = $start + $count;

      my $rowid  = 'row_'.(pad $args->{link_num}, 5, 0, 'left');

      $rows->{ $rowid } = $self->$_new_grid_row( $req, $args, $rowid, $row );
      $count++;
   }

   $rows->{meta} = { count => $count, id => "${id}${start}", offset => $start };

   return $rows;
}

sub build_grid_table {
   my ($self, $req, $args) = @_; my $params = $req->query_params;

   my $form   = $args->{form};
   my $field  = $params->( 'id' );
   my $psize  = $params->( 'page_size' ) || 10;
   my $label  = $req->loc( $args->{label} );
   my $id     = "${form}_${field}";
   my $count  = 0;
   my @values = ();

   while ($count < $args->{total} && $count < $psize) {
      push @values, { item => DOTS, item_num => ++$count, };
   }

   return {
      'meta'         => {
         id          => $id,
         field_value => $params->( 'field_value', { optional => TRUE } ) // NUL,
         totalcount  => $args->{total}, },
      "${id}_header" => {
         id          => "${id}_header",
         text        => $req->loc( 'Loading' ).DOTS, },
      "${id}_grid"   => {
         id          => "${id}_grid",
         data        => $_new_grid_table->( $label, \@values ), },
   };
}

sub check_field : Role(anon) {
   my ($self, $req) = @_; my $mesg;

   my $id = $req->query_params->( 'id' ); my $meta = { id => "${id}_ajax" };

   try   { $self->$_check_field( $req ) }
   catch {
      my $e = $_; my $args = { params => $e->args, quote_bind_values => TRUE };

      $self->debug and $self->log->debug( "${e}" );
      $mesg = $req->loc( $e->error, $args );
      $meta->{class_name} = 'field_error';
   };

   return { code => HTTP_OK,
            form => [ { fields => [ { content => $mesg } ] } ],
            page => { meta => $meta },
            view => 'json' };
}

sub create_record {
   my ($self, $args) = @_; my $rs = $args->{rs}; my $rec = {};

   for my $col ($rs->result_source->columns) {
      $self->$_set_column( $args, $rec, $col );
   }

   return $rs->create( $rec );
}

sub find_and_update_record {
   my ($self, $args) = @_; my $rs = $args->{rs};

   my $rec = $rs->find( $args->{id} ) or return;

   for my $col ($rs->result_source->columns) {
      $self->$_set_column( $args, $rec, $col );
   }

   $rec->update;
   return $rec;
}

1;

__END__

=pod

=encoding utf8

=head1 Name

App::MCP::Role::FormBuilder - One-line description of the modules purpose

=head1 Synopsis

   use App::MCP::Role::FormBuilder;
   # Brief but working code examples

=head1 Version

This documents version v0.1.$Rev: 18 $ of L<App::MCP::Role::FormBuilder>

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
