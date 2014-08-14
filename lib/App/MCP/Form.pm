package App::MCP::Form;

use feature 'state';
use namespace::autoclean;

use Moo;
use App::MCP::Form::Field;
use Class::Usul::Constants qw( DEFAULT_L10N_DOMAIN TRUE );
use Class::Usul::Functions qw( first_char is_arrayref is_hashref throw );
use Class::Usul::Types     qw( ArrayRef CodeRef HashRef Int
                               NonEmptySimpleStr SimpleStr Object );
use File::DataClass::Types qw( Directory );
use Scalar::Util           qw( blessed weaken );

has 'config'       => is => 'ro',   isa => HashRef, default => sub { {} };

has 'data'         => is => 'ro',   isa => ArrayRef, default => sub { [] };

has 'first_field'  => is => 'ro',   isa => SimpleStr;

has 'js_object'    => is => 'ro',   isa => NonEmptySimpleStr,
   default         => 'behaviour';

has 'l10n'         => is => 'lazy', isa => CodeRef;

has 'list_key'     => is => 'ro',   isa => NonEmptySimpleStr,
   default         => 'fields';

has 'literal_js'   => is => 'ro',   isa => ArrayRef, default => sub { [] };

has 'max_pwidth'   => is => 'ro',   isa => Int, default => 1024;

has 'model'        => is => 'ro',   isa => Object, required => TRUE;

has 'name'         => is => 'ro',   isa => NonEmptySimpleStr, required => TRUE;

has 'ns'           => is => 'lazy', isa => NonEmptySimpleStr,
   builder         => sub { $_[ 0 ]->req->l10n_domain };

has 'pwidth'       => is => 'ro',   isa => Int, default => 40;

has 'req'          => is => 'ro',   isa => Object, required => TRUE,
   weak_ref        => TRUE;

has 'result_class' => is => 'ro',   isa => SimpleStr;

has 'template'     => is => 'ro',   isa => NonEmptySimpleStr, default => 'form';

has 'template_dir' => is => 'lazy', isa => Directory,
   builder         => sub {
      $_[ 0 ]->model->config->root->catdir( 'templates' ) },
   coerce          => Directory->coercion;

has 'width'        => is => 'lazy', isa => Int,
   builder         => sub { $_[ 0 ]->req->ui_state->{width} // 1024 };

# Construction
around 'BUILDARGS' => sub {
   my ($orig, $self, $model, $req, $form_name, $row) = @_; my $attr = {};

   $attr->{model } = $model,
   $attr->{name  } = $form_name;
   $attr->{req   } = $req;
   $attr->{row   } = $row;
   $attr->{config} = $self->load_config
      ( $model->usul, $req->l10n_domain, $req->locale );

   exists $attr->{config}->{ $form_name }
      or throw error => 'Form name [_1] unknown', args => [ $form_name ];

   my $meta = $attr->{config}->{ $form_name }->{meta} // {};

   $attr->{ $_ } //= $meta->{ $_ } for (keys %{ $meta });

   return $attr;
};

sub BUILD {
   my ($self, $attr) = @_; my $config = $self->config;

   my $cache = {}; my $count = 0; my $form_name = $self->name;

   $self->l10n; $self->ns; $self->template_dir; $self->width; # Visit the lazy

   for my $fields (@{ $config->{ $form_name }->{regions} }) {
      my $region = $self->data->[ $count++ ] = { fields => [] };

      for my $name (__field_list( $config->{_fields}, $fields, $attr->{row} )) {
         my $field = App::MCP::Form::Field->new
            ( $config->{_fields}, $form_name, $name );

         $self->_assign_value( $field, $attr->{row} );

         my $hook  = "_${form_name}_".$field->name.'_field_hook';
         my $code; $code = $self->model->can( $hook )
            and $field = $code->( $self->model, $cache, $field );
         my $props = $field->properties;

         $field and $cache->{ $field->name } = $props
                and push @{ $region->{fields} }, { content => $props };
      }
   }

   return;
}

sub _build_l10n {
   my $self = shift; my $req = $self->req; weaken( $req ); state $cache //= {};

   return sub {
      my ($opts, $text, @args) = @_;

      my $key = $req->l10n_domain.'.'.$req->locale.'.'.$text;

      (exists $cache->{ $key } and defined $cache->{ $key })
         or $cache->{ $key } = $req->loc( $text, @args );

      return $cache->{ $key };
   };
}

# Public methods
sub load_config {
   my ($self, $builder, $domain, $locale) = @_;

   state $cache //= {}; my $key = $domain.$locale;

   exists $cache->{ $key } and return $cache->{ $key };

   my $config   = $builder->config;
   my $def_path = $config->ctrldir->catfile( 'form.json' );
   my $ns_path  = $config->ctrldir->catfile( "${domain}.json" );

   $ns_path->exists
      or ($builder->log->warn( "File ${ns_path} not found" ) and return {});

   my $attr  = { builder     => $builder,
                 cache_class => 'none',
                 lang        => $locale,
                 localedir   => $config->localedir };
   my $class = File::Gettext::Schema->new( $attr );

   return $cache->{ $key } = $class->load( $def_path, $ns_path );
}

# Private methods
sub _assign_value {
   my ($self, $field, $row) = @_;

   my $value = __extract_value( $field, $row );
   my $name  = $field->name; $name =~ s{ \. }{_}gmx;
   my $hook  = '_'.$self->name.'_'.$name.'_assign_hook';
   my $code; $code = $self->model->can( $hook )
      and $value = $code->( $self->model, $self->req, $field, $row, $value );

   defined $value or return;

   if (is_hashref $value) { $field->add_properties( $value ) }
   else { $field->key_value( "${value}" ) }

   return;
}

# Private functions
sub __extract_value {
   my ($field, $row) = @_;

   my $value = $field->key_value; my $col = $field->name;

   if ($row and blessed $row and $row->can( $col )) {
      $value = $row->$col();
   }
   elsif (is_hashref $row and exists $row->{ $col }) {
      $value = $row->{ $col };
   }

   return $value;
}

sub __field_list {
   my ($conf, $fields, $row) = @_; my $names;

   if (is_arrayref $fields) {
      $names = $fields->[ 0 ] ? $fields : [ sort keys %{ $row } ];
   }
   else { $names = $conf->{ $fields } };

   return grep { not m{ \A (?: _ | related_resultsets ) }mx } @{ $names };
}

1;

__END__

=pod

=encoding utf8

=head1 Name

App::MCP::Form - One-line description of the modules purpose

=head1 Synopsis

   use App::MCP::Form;
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
