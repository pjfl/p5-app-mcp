package App::MCP::Role::FormBuilder;

use 5.01;
use namespace::sweep;

use App::MCP::Constants;
use Class::Usul::Functions qw( is_arrayref is_hashref first_char pad throw );
use Class::Usul::Response::Table;
use File::Gettext::Schema;
use Scalar::Util           qw( blessed weaken );
use Unexpected::Functions  qw( Unspecified );
use Moo::Role;

requires qw( config get_stash log usul );

# Construction
around 'get_stash' => sub {
   my ($orig, $self, $req, $page, $form_name, $rec) = @_;

   $form_name or return $orig->( $self, $req, $page );

   my $form = $self->_build_form( $req, $form_name, $rec );

   $page->{first_field} = $form->{first_field};

   my $stash = $orig->( $self, $req, $page ); $stash->{form} = $form;

   return $stash;
};

# Public methods
sub build_chooser {
   my ($self, $req) = @_; my $params = $req->params;

   my $form  = __get_or_throw( $params, 'form'  );
   my $field = __get_or_throw( $params, 'field' );
   my $show  = "function() { this.window.dialogs[ '${field}' ].show() }";
   my $id    = "${form}_${field}";

   return {
      'meta' => { id => __get_or_throw( $params, 'id' ) },
      $id    => { id     => $id,
               config => { event      => $params->{event} || "'load'",
                           fieldValue => "'".($params->{val} || NUL)."'",
                           gridToggle => $params->{toggle} ? 'true' : 'false',
                           onComplete => $show, }, } };
}

sub build_grid_rows {
   my ($self, $req) = @_; my $params = $req->params;

   my $id        = __get_or_throw( $params, 'id'        );
   my $cb_method = __get_or_throw( $params, 'method'    );
   my $form      = __get_or_throw( $params, 'form'      );
   my $page      = __get_or_throw( $params, 'page'      ) || 0;
   my $page_size = __get_or_throw( $params, 'page_size' ) || 10;
  (my $field     = $id) =~ s{ _grid \z }{}msx;
      $field     = (split m{ _ }mx, $field)[ 1 ];
   my $start     = $page * $page_size;
   my $rows      = {};
   my $count     = 0;

   for my $value (@{ $params->{values} || [] }) {
      my $link_num = $start + $count;
      my $item     = $self->$cb_method( $req, $params, $value, $link_num );
      my $rv       = (delete $item->{value}) || $item->{text};
      my $rowid    = "row_${link_num}";

      $item->{class    } ||= 'chooser_grid fade submit';
      $item->{config   }   = { args   => "[ '${form}', '${field}', '${rv}' ]",
                               method => "'returnValue'", };
      $item->{container}   = FALSE;
      $item->{id       }   = "${id}_link${link_num}";
      $item->{type     }   = 'anchor';
      $item->{widget   }   = TRUE;
      $rows->{ $rowid  }   = {
         class   => 'grid',
         classes => { item     => 'grid_cell',
                      item_num => 'grid_cell lineNumber first' },
         fields  => [ qw( item_num item ) ],
         id      => $rowid,
         type    => 'tableRow',
         values  => { item => $item, item_num => $link_num + 1, }, };
      $count++;
   }

   $rows->{meta} = { count => $count, id => "${id}${start}", offset => $start };

   return $rows;
}

sub build_grid_table {
   my ($self, $req) = @_; my $params = $req->params;

   my $field  = __get_or_throw( $params, 'id' );
   my $form   = __get_or_throw( $params, 'form' );
   my $label  = __get_or_throw( $params, 'label' );
   my $total  = __get_or_throw( $params, 'total' );
   my $psize  = __get_or_throw( $params, 'page_size'   ) || 10;
   my $value  = __get_or_throw( $params, 'field_value' ) || NUL;
   my $id     = "${form}_${field}";
   my $count  = 0;
   my @values = ();

   while ($count < $total && $count < $psize) {
      push @values, { item => DOTS, item_num => ++$count, };
   }

   my $grid = $self->_new_grid_table( $req->loc( $label ), \@values );

   return {
      'meta'         => {
         id          => $id,
         field_value => $value,
         totalcount  => $total, },
      "${id}_header" => {
         id          => "${id}_header",
         text        => $req->loc( 'Loading' ).DOTS, },
      "${id}_grid"   => {
         id          => "${id}_grid",
         data        => $grid, },
   };
}

sub create_record {
   my ($self, $args) = @_; my $rs = $args->{rs};

   my $param = $args->{param}; my $rec = {};

   my $deflate = $args->{deflate} // sub { $_[ 0 ]->{ $_[ 1 ] } };

   for my $col ($rs->result_source->columns) {
      my $value = NUL; defined( $value = $deflate->( $param, $col ) )
         and $rec->{ $col } = "${value}";
   }

   return $rs->create( $rec );
}

sub find_and_update_record {
   my ($self, $args, $id) = @_; my $rs = $args->{rs};

   my $param = $args->{param}; my $rec = $rs->find( $id ) or return;

   my $deflate = $args->{deflate} // sub { $_[ 0 ]->{ $_[ 1 ] } };

   for my $col ($rs->result_source->columns) {
      my $value = NUL; defined( $value = $deflate->( $param, $col ) )
         and $rec->$col( "${value}" );
   }

   $rec->update;
   return $rec;
}

# Private methods
sub _build_field {
   my ($self, $req, $forms, $form_name, $field_name, $rec) = @_;

   my $fqfn  = first_char $field_name eq '+'
             ? substr $field_name, 1 : "${form_name}.${field_name}";
   my $col   = $field_name; $col =~ s{ \A \+ }{}mx;
   my $field = { %{ $forms->{fields}->{ $fqfn } // {} }, name => $col };

   exists $field->{form} or exists $field->{group} or exists $field->{widget}
       or $field->{widget} = TRUE;

   my $key   = __make_key( $field );
   my $value = $self->_extract_value( $rec, $col, $field->{ $key } );

   defined $value and $self->_deref_value( $req, $field, $key, $value );

   return { content => $field };
}

sub _build_form {
   my ($self, $req, $form_name, $rec) = @_;

   my $count = 0;
   my $forms = $self->_forms( $req );
   my $form  = $self->_new_form( $req, $form_name );

   exists $forms->{regions}->{ $form_name }
      or throw error => 'Form name [_1] unknown', args => [ $form_name ];

   $form->{first_field} = $forms->{first_fields}->{ $form_name } || NUL;

   for my $fields (@{ $forms->{regions}->{ $form_name }}) {
      my $region = $form->{data}->[ $count++ ] = { fields => [] };
      my @keys   = $fields->[ 0 ] ? @{ $fields } : sort keys %{ $rec };

      for my $name (@keys) {
         push @{ $region->{fields} },
            $self->_build_field( $req, $forms, $form_name, $name, $rec );
      }
   }

   return $form;
}

sub _deref_value {
   my ($self, $req, $field, $key, $value) = @_;

   if (first_char "${value}" eq '&') {
      my $method = substr "${value}", 1; $value = $self->$method( $req );
   }

   if (is_hashref $value) {
      $field->{ $_ } = $value->{ $_ } for (keys %{ $value });
   }
   else { $field->{ $key } = "${value}" }

   return;
}

sub _extract_value {
   my ($self, $rec, $col, $default) = @_; my $value = $default;

   if ($rec and blessed $rec and $rec->can( $col )) {
      $value = $rec->$col();
   }
   elsif (is_hashref $rec and exists $rec->{ $col }) {
      $value = $rec->{ $col };
   }

   return $value;
}

sub _forms {
   my ($self, $req) = @_; state $cache //= {}; my $locale = $req->locale;

   exists $cache->{ $locale } and return $cache->{ $locale };

   my $file = $req->l10n_domain;
   my $path = $self->config->ctrldir->catfile( "${file}.json" );

   $path->exists
      or ($self->log->warn( "File ${path} not found" ) and return {});

   my $attr  = { builder     => $self->usul,
                 cache_class => 'none',
                 lang        => $locale,
                 localedir   => $self->config->localedir };
   my $forms = File::Gettext::Schema->new( $attr )->load( $path );

   return $cache->{ $locale } = $forms;
}

sub _new_form {
   my ($self, $req, $form_name) = @_; weaken( $req );

   return { data       => [],
            js_object  => 'behaviour',
            l10n       => sub { __loc( $req, @_ ) },
            list_key   => 'fields',
            literal_js => [],
            name       => $form_name,
            ns         => $req->l10n_domain,
            width      => $req->ui_state->{width} || 1024, };
}

sub _new_grid_table {
   my ($self, $label, $values) = @_;

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
}

# Private functions
sub __get_or_throw {
   my ($params, $name) = @_;

   defined (my $param = $params->{ $name })
      or throw class => Unspecified, args => [ $name ];

   return $param;
}

sub __make_key {
   my $field = shift; my $type = $field->{type} // NUL;

   return $type eq 'label'   ? 'text'
        : $type eq 'chooser' ? 'href'
                             : 'default';
}

sub __loc { # Localize the key and substitute the placeholder args
   my ($req, $opts, $key, @args) = @_; my $car = $args[ 0 ];

   my $args = (is_hashref $car) ? { %{ $car } }
            : { params => (is_arrayref $car) ? $car : [ @args ] };

   $args->{domain_names} ||= [ DEFAULT_L10N_DOMAIN, $opts->{ns} ];
   $args->{locale      } ||= $opts->{language};

   return $req->localize( $key, $args );
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

This documents version v0.1.$Rev: 8 $ of L<App::MCP::Role::FormBuilder>

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
