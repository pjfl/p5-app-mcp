package App::MCP::Form;

use feature 'state';
use namespace::autoclean;

use App::MCP::Form::Field;
use Class::Usul::Constants qw( TRUE );
use Class::Usul::Functions qw( first_char is_arrayref is_hashref throw );
use Class::Usul::Types     qw( ArrayRef CodeRef HashRef Int
                               NonEmptySimpleStr SimpleStr Object );
use File::DataClass::Types qw( Directory );
use Scalar::Util           qw( blessed weaken );
use Moo;

# Attribute constructors
my $_build_l10n = sub {
   my $self = shift; state $cache //= {}; my $req = $self->req; weaken( $req );

   return sub {
      my ($opts, $text, @args) = @_; # Ignore $opts->{ ns, language }

      my $key = $req->model_name.'.'.$req->locale.".${text}";

      (exists $cache->{ $key } and defined $cache->{ $key })
         or $cache->{ $key } = $req->loc( $text, @args );

      return $cache->{ $key };
   };
};

my $_build_uri_for = sub {
   my $self = shift; my $req = $self->req; weaken( $req );

   return sub { $req->uri_for( @_ ) };
};

# Public methods
has 'config'       => is => 'ro',   isa => HashRef, default => sub { {} };

has 'data'         => is => 'ro',   isa => ArrayRef, default => sub { [] };

has 'first_field'  => is => 'ro',   isa => SimpleStr;

has 'js_object'    => is => 'ro',   isa => NonEmptySimpleStr,
   default         => 'behaviour';

has 'l10n'         => is => 'lazy', isa => CodeRef, builder => $_build_l10n;

has 'list_key'     => is => 'ro',   isa => NonEmptySimpleStr,
   default         => 'fields';

has 'literal_js'   => is => 'ro',   isa => ArrayRef, default => sub { [] };

has 'max_pwidth'   => is => 'ro',   isa => Int, default => 1024;

has 'model'        => is => 'ro',   isa => Object, required => TRUE;

has 'name'         => is => 'ro',   isa => NonEmptySimpleStr, required => TRUE;

has 'ns'           => is => 'lazy', isa => NonEmptySimpleStr,
   builder         => sub { $_[ 0 ]->req->model_name };

has 'pwidth'       => is => 'ro',   isa => Int, default => 40;

has 'req'          => is => 'ro',   isa => Object, required => TRUE,
   weak_ref        => TRUE;

has 'result_class' => is => 'ro',   isa => SimpleStr;

has 'template'     => is => 'ro',   isa => NonEmptySimpleStr, default => 'form';

has 'template_dir' => is => 'lazy', isa => Directory, coerce => TRUE,
   builder         => sub {
      $_[ 0 ]->model->config->root->catdir( 'templates' ) };

has 'uri_for'      => is => 'lazy', isa => CodeRef, builder => $_build_uri_for;

has 'width'        => is => 'lazy', isa => Int,
   builder         => sub { $_[ 0 ]->req->ui_state->{width} // 1024 };

# Private functions
my $_extract_value = sub {
   my ($field, $row) = @_;

   my $value = $field->key_value; my $col = $field->name;

   if ($row and blessed $row and $row->can( $col )) {
      $value = $row->$col();
   }
   elsif (is_hashref $row and exists $row->{ $col }) {
      $value = $row->{ $col };
   }

   return $value;
};

my $_field_list = sub {
   my ($conf, $fields, $row) = @_; my $names;

   if (is_arrayref $fields) {
      $names = $fields->[ 0 ] ? $fields : [ sort keys %{ $row } ];
   }
   else { $names = $conf->{ $fields } };

   return grep { not m{ \A (?: _ | related_resultsets ) }mx } @{ $names };
};

my $_load_config = sub {
   my $req      = shift;
   my $domain   = $req->model_name;
   my $language = $req->language;
   my $key      = "${domain}.${language}";

   state $cache //= {}; exists $cache->{ $key } and return $cache->{ $key };

   my $builder  = $req->usul;
   my $config   = $builder->config;
   my $def_path = $config->ctrldir->catfile( 'form.json' );
   my $ns_path  = $config->ctrldir->catfile( "${domain}.json" );

   $ns_path->exists or ($builder->log->warn( "File ${ns_path} not found" )
      and return {});

   my $class    = File::Gettext::Schema->new( {
      builder     => $builder,
      cache_class => 'none',
      lang        => $language,
      localedir   => $config->localedir } );

   return $cache->{ $key } = $class->load( $def_path, $ns_path );
};

# Private methods
my $_assign_value = sub {
   my ($self, $field, $row) = @_;

   my $value = $_extract_value->( $field, $row );
   my $name  = $field->name; $name =~ s{ \. }{_}gmx;
   my $hook  = '_'.$self->name."_${name}_assign_hook";
   my $code; $code = $self->model->can( $hook )
      and $value = $code->( $self->model, $self->req, $field, $row, $value );

   defined $value or return;

   if (is_hashref $value) { $field->add_properties( $value ) }
   else { $field->key_value( "${value}" ) }

   return;
};

# Construction
around 'BUILDARGS' => sub {
   my ($orig, $self, $model, $req, $form_name, $row) = @_; my $attr = {};

   $attr->{model } = $model,
   $attr->{name  } = $form_name;
   $attr->{req   } = $req;
   $attr->{row   } = $row;
   $attr->{config} = $_load_config->( $req );

   exists $attr->{config}->{ $form_name }
      or throw 'Form name [_1] unknown', [ $form_name ];

   my $meta = $attr->{config}->{ $form_name }->{meta} // {};

   $attr->{ $_ } //= $meta->{ $_ } for (keys %{ $meta });

   return $attr;
};

sub BUILD {
   my ($self, $attr) = @_; my $cache = {}; my $config = $self->config;

   my $count = 0; my $form_name = $self->name; my $row = $attr->{row};

   # Visit the lazy so ::FormHandler can pass $self to HTML::FormWidgets->build
   $self->l10n; $self->ns; $self->template_dir; $self->uri_for; $self->width;

   for my $fields (@{ $config->{ $form_name }->{regions} }) {
      my $region = $self->data->[ $count++ ] = { fields => [] };

      for my $name ($_field_list->( $config->{_fields}, $fields, $row )) {
         my $field = App::MCP::Form::Field->new
            ( $config->{_fields}, $form_name, $name );

         $self->$_assign_value( $field, $row );

         my $hook  = "_${form_name}_".$field->name.'_field_hook';
         my $code; $code = $self->model->can( $hook )
            and $field = $code->( $self->model, $cache, $field );
         my $props;

         $field and $props = $cache->{ $field->name } = $field->properties
                and push @{ $region->{fields} }, { content => $props };
      }
   }

   return;
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
