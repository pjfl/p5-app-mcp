package App::MCP::Form;

use namespace::autoclean;

use App::MCP::Form::Field;
use Class::Usul::Constants qw( TRUE );
use Class::Usul::Functions qw( first_char is_arrayref is_hashref throw );
use Class::Usul::Types     qw( ArrayRef CodeRef HashRef Int
                               NonEmptySimpleStr SimpleStr Object );
use File::DataClass::Types qw( Directory );
use File::Gettext::Schema;
use Scalar::Util           qw( blessed weaken );
use Moo;

# Private package variables
my $_config_cache = {};
my $_l10n_cache   = {};

# Attribute constructors
my $_build_l10n = sub {
   my $self = shift; my $req = $self->req; weaken $req;

   return sub {
      my ($opts, $text, @args) = @_; # Ignore $opts->{ ns, language }

      my $key = $req->domain.'.'.$req->locale.".${text}";

      (exists $_l10n_cache->{ $key } and defined $_l10n_cache->{ $key })
         or $_l10n_cache->{ $key } = $req->loc( $text, @args );

      return $_l10n_cache->{ $key };
   };
};

my $_build_uri_for = sub {
   my $self = shift; my $req = $self->req; weaken $req;

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
   builder         => sub { $_[ 0 ]->req->domain };

has 'pwidth'       => is => 'ro',   isa => Int, default => 40;

has 'req'          => is => 'ro',   isa => Object, required => TRUE,
   weak_ref        => TRUE;

has 'result_class' => is => 'ro',   isa => SimpleStr;

has 'skin'         => is => 'lazy', isa => NonEmptySimpleStr,
   builder         => sub { $_[ 0 ]->model->config->skin };

has 'template'     => is => 'ro',   isa => NonEmptySimpleStr, default => 'form';

has 'template_dir' => is => 'lazy', isa => Directory, coerce => TRUE,
   builder         => sub {
      $_[ 0 ]->model->config->root->catdir( 'templates', $_[ 0 ]->skin ) };

has 'uri_for'      => is => 'lazy', isa => CodeRef, builder => $_build_uri_for;

has 'width'        => is => 'lazy', isa => Int, builder => sub {
   $_[ 0 ]->req->get_cookie_hash( 'mcp_state' )->{width} // 1024 };

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
   my ($orig, $self, $args) = @_; my $attr = { %{ $args } };

   $attr->{config} = $self->load_config( $args->{model}, $args->{req} );

   exists $attr->{config}->{ $args->{name} }
       or throw 'Form name [_1] unknown', [ $args->{name} ];

   my $defaults = $attr->{config}->{ $args->{name} }->{defaults} // {};

   $attr->{ $_ } //= $defaults->{ $_ } for (keys %{ $defaults });

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

         # TODO: This is unused and we have the assign hook
         # The cache is only useful one fully populated
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

sub load_config {
   my ($self, $model, $req, $domain) = @_; $domain //= $req->domain;

   my $language = $req->language; my $key = "${domain}.${language}";

   exists $_config_cache->{ $key } and return $_config_cache->{ $key };

   my $conf     = $model->config;
   my $def_path = $conf->ctrldir->catfile( 'form.json' );
   my $ns_path  = $conf->ctrldir->catfile( "${domain}.json" );

   $ns_path->exists or ($model->log->warn( "File ${ns_path} not found" )
      and return {});

   my $class    = File::Gettext::Schema->new( {
      builder     => $model,
      cache_class => 'none',
      lang        => $language,
      localedir   => $conf->localedir } );

   return $_config_cache->{ $key } = $class->load( $def_path, $ns_path );
}

1;

__END__

=pod

=encoding utf-8

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
