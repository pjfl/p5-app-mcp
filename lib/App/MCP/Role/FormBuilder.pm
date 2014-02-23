package App::MCP::Role::FormBuilder;

use 5.010001;
use namespace::sweep;

use App::MCP::Constants;
use App::MCP::Functions    qw( get_or_throw );
use Class::Usul::Functions qw( ensure_class_loaded is_arrayref
                               is_hashref first_char pad throw );
use Class::Usul::Response::Table;
use Data::Validation;
use File::Gettext::Schema;
use HTTP::Status           qw( HTTP_OK );
use Scalar::Util           qw( blessed weaken );
use TryCatch;
use Moo::Role;

requires qw( check_field config debug get_stash log usul );

# Construction
around 'get_stash' => sub {
   my ($orig, $self, $req, $page, $form_name, $rec) = @_;

   $form_name or return $orig->( $self, $req, $page );

   my $form = $self->_new_form( $req, $form_name, $rec );

   $page->{first_field} = $form->{first_field};

   my $stash = $orig->( $self, $req, $page ); $stash->{form} = $form;

   return $stash;
};

# Public methods
sub build_chooser {
   my ($self, $req) = @_; my $params = $req->params;

   my $form  = get_or_throw( $params, 'form'  );
   my $field = get_or_throw( $params, 'field' );
   my $show  = "function() { this.window.dialogs[ '${field}' ].show() }";
   my $val   = $params->{val} // NUL; $val =~ s{ [\*] }{%}gmx;
   my $id    = "${form}_${field}";

   return {
      'meta'    => { id => get_or_throw( $params, 'id' ) },
      $id       => {
         id     => $id,
         config => { button     => "'".($params->{button} // NUL)."'",
                     event      => $params->{event} || "'load'",
                     fieldValue => "'${val}'",
                     gridToggle => $params->{toggle} ? 'true' : 'false',
                     onComplete => $show }, } };
}

sub build_grid_rows {
   my ($self, $req) = @_; my $params = $req->params;

   my $id        = get_or_throw( $params, 'id'        );
   my $page      = get_or_throw( $params, 'page'      ) || 0;
   my $page_size = get_or_throw( $params, 'page_size' ) || 10;
   my $start     = $page * $page_size;
   my $rows      = {};
   my $count     = 0;

   for my $row (@{ $params->{values} // [] }) {
      my $link_num = $start + $count;
      my $rowid    = 'row_'.(pad $link_num, 5, 0, 'left');

      $rows->{ $rowid } = $self->_new_grid_row( $req, $link_num, $rowid, $row );
      $count++;
   }

   $rows->{meta} = { count => $count, id => "${id}${start}", offset => $start };

   return $rows;
}

sub build_grid_table {
   my ($self, $req) = @_; my $params = $req->params;

   my $field  = get_or_throw( $params, 'id' );
   my $form   = get_or_throw( $params, 'form' );
   my $label  = get_or_throw( $params, 'label' );
   my $total  = get_or_throw( $params, 'total' );
   my $psize  = get_or_throw( $params, 'page_size'   ) || 10;
   my $value  = get_or_throw( $params, 'field_value' ) || NUL;
   my $id     = "${form}_${field}";
   my $count  = 0;
   my @values = ();

   while ($count < $total && $count < $psize) {
      push @values, { item => DOTS, item_num => ++$count, };
   }

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
         data        => __new_grid_table( $req->loc( $label ), \@values ), },
   };
}

sub create_record {
   my ($self, $args) = @_; my $rs = $args->{rs}; my $rec = {};

   for my $col ($rs->result_source->columns) {
      $self->_set_column( $args, $rec, $col );
   }

   return $rs->create( $rec );
}

sub find_and_update_record {
   my ($self, $args, $id) = @_; my $rs = $args->{rs};

   my $rec = $rs->find( $id ) or return;

   for my $col ($rs->result_source->columns) {
      $self->_set_column( $args, $rec, $col );
   }

   $rec->update;
   return $rec;
}

sub formbuilder_check_field {
   my ($self, $req) = @_; my $mesg;

   my $id   = get_or_throw( $req->params, 'id' );
   my $meta = { id => "${id}_ajax" };

   try        { $self->_check_field( $req ) }
   catch ($e) {
      my $args = { params => $e->args, quote_bind_values => TRUE };

      $self->debug and $self->log->debug( "${e}" );
      $mesg = $req->loc( $e->error, $args );
      $meta->{class_name} = 'field_error';
   }

   return { code => HTTP_OK,
            form => [ { fields => [ $mesg ] } ],
            page => { meta => $meta } };
}

# Private methods
sub _check_field {
   my ($self, $req) = @_; my $params = $req->params;

   my $domain = get_or_throw( $params, 'domain' );
   my $form   = get_or_throw( $params, 'form'   );
   my $id     = get_or_throw( $params, 'id'     );
   my $val    = get_or_throw( $params, 'val'    );
   my $meta   = $self->_forms( $domain, $req->locale )->{meta};
   my $class  = $self->schema_class.'::Result::'
               .$meta->{ $form }->{result_class};

   ensure_class_loaded( $class ); my $attr = $class->validation_attributes;

   return Data::Validation->new( $attr )->check_field( $id, $val );
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

sub _forms {
   my ($self, $domain, $locale) = @_; state $cache //= {};

   my $key   = $domain.$locale;

   exists $cache->{ $key } and return $cache->{ $key };

   my $path  = $self->config->ctrldir->catfile( "${domain}.json" );

   $path->exists
      or ($self->log->warn( "File ${path} not found" ) and return {});

   my $attr  = { builder     => $self->usul,
                 cache_class => 'none',
                 lang        => $locale,
                 localedir   => $self->config->localedir };
   my $forms = File::Gettext::Schema->new( $attr )->load( $path );

   return $cache->{ $key } = $forms;
}

sub _initialize_form {
   my ($self, $req, $form_name) = @_; weaken( $req );

   my $domain = $req->l10n_domain;
   my $form   = { data        => [],
                  js_object   => 'behaviour',
                  l10n        => sub { __loc( $req, @_ ) },
                  list_key    => 'fields',
                  literal_js  => [],
                  name        => $form_name,
                  ns          => $domain,
                  width       => $req->ui_state->{width} // 1024, };
   my $locale = $req->locale;
   my $meta   = $self->_forms( $domain, $locale )->{meta}->{ $form_name };

   $form->{ $_ } = $meta->{ $_ } for (keys %{ $meta });

   return $form;
}

sub _instantiate_field {
   my ($self, $field, $req, $col, $rec) = @_;

   exists $field->{name} or $field->{name} = $col;
   exists $field->{form} or exists $field->{group} or exists $field->{widget}
       or $field->{widget} = TRUE;

   my $key   = __extract_key  ( $field );
   my $value = __extract_value( $field->{ $key }, $rec, $col );

   defined $value and $self->_deref_value( $req, $field, $key, $value );

   return;
}

sub _new_form {
   my ($self, $req, $form_name, $rec) = @_; my $cache = {}; my $count = 0;

   my $forms = $self->_forms( $req->l10n_domain, $req->locale );

   exists $forms->{regions}->{ $form_name }
      or throw error => 'Form name [_1] unknown', args => [ $form_name ];

   my $new = $self->_initialize_form( $req, $form_name );

   for my $fields (@{ $forms->{regions}->{ $form_name }}) {
      my $region = $new->{data}->[ $count++ ] = { fields => [] };
      my @keys   = $fields->[ 0 ] ? @{ $fields } : sort keys %{ $rec };

      for my $name (grep { not m{ \A _ }mx } @keys) {
         my $field = __new_field( $forms, $form_name, $name );
         my $col   = $name; $col =~ s{ \A \+ }{}mx;

         $self->_instantiate_field( $field, $req, $col, $rec );

         my $hook  = "_${form_name}_field_hook_".$field->{name};

         $self->can( $hook ) and $field = $self->$hook( $cache, $field );
         $field and $cache->{ $field->{name} } = $field
                and push @{ $region->{fields} }, { content => $field };
      }
   }

   return $new;
}

sub _new_grid_row {
   my ($self, $req, $link_num, $rowid, $row) = @_; my $params = $req->params;

   my $id     = get_or_throw( $params, 'id'     );
   my $form   = get_or_throw( $params, 'form'   );
   my $method = get_or_throw( $params, 'method' );
   my $button = $params->{button} // NUL;
  (my $field  = $id) =~ s{ _grid \z }{}msx;
      $field  = (split m{ _ }mx, $field)[ 1 ];
   my $item   = $self->$method( $req, $link_num, $row );
   my $rv     = (delete $item->{value}) || $item->{text};
   my $args   = "[ '${form}', '${field}', '${rv}', '${button}' ]";

   $item->{class    } //= 'chooser_grid fade submit';
   $item->{config   }   = { args => $args, method => "'returnValue'", };
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
}

sub _set_column {
   my ($self, $args, $rec, $col) = @_;

   my $prefix = $args->{method};
   my $method = $prefix ? "${prefix}${col}" : undef;
   my $value  = $method && $self->can( $method )
              ? $self->$method( $args->{param} ) : $args->{param}->{ $col };

   defined $value or return;

   if (blessed $rec) { $rec->$col( "${value}" ) }
   else { $rec->{ $col } = "${value}" }

   return;
}

# Private functions
sub __extract_key {
   my $field = shift; my $type = $field->{type} // NUL;

   return $type eq 'button'  ? 'name'
        : $type eq 'chooser' ? 'href'
        : $type eq 'label'   ? 'text'
                             : 'default';
}

sub __extract_value {
   my ($default, $rec, $col) = @_; my $value = $default;

   if ($rec and blessed $rec and $rec->can( $col )) {
      $value = $rec->$col();
   }
   elsif (is_hashref $rec and exists $rec->{ $col }) {
      $value = $rec->{ $col };
   }

   return $value;
}

sub __loc { # Localize the key and substitute the placeholder args
   my ($req, $opts, $key, @args) = @_; my $car = $args[ 0 ];

   my $args = (is_hashref $car) ? { %{ $car } }
            : { params => (is_arrayref $car) ? $car : [ @args ] };

   $args->{domain_names} ||= [ DEFAULT_L10N_DOMAIN, $opts->{ns} ];
   $args->{locale      } ||= $opts->{language};

   return $req->localize( $key, $args );
}

sub __new_field {
   my ($forms, $form_name, $field_name) = @_;

   my $fqfn = first_char $field_name eq '+'
            ? substr $field_name, 1 : "${form_name}.${field_name}";

   return { %{ $forms->{fields}->{ $fqfn } // {} } };
}

sub __new_grid_table {
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
