package App::MCP::Functions;

use strictures;
use parent 'Exporter::Tiny';

use App::MCP::Constants    qw( EXCEPTION_CLASS FAILED FALSE LANG NUL
                               OK SPC TRUE VARCHAR_MAX_SIZE );
use Class::Usul::Functions qw( first_char merge_attributes split_on__ throw );
use English                qw( -no_match_vars );
use Module::Pluggable::Object;
use Storable               qw( nfreeze );
use Unexpected::Functions  qw( Unspecified );
use URI::Escape            qw( );
use URI::http;
use URI::https;

our @EXPORT_OK = ( qw( enumerated_data_type env_var extract_lang
                       foreign_key_data_type get_hashed_pw get_salt
                       load_components new_uri
                       nullable_foreign_key_data_type
                       nullable_varchar_data_type numerical_id_data_type
                       qualify_job_name serial_data_type
                       set_on_create_datetime_data_type terminate
                       trigger_input_handler trigger_output_handler
                       varchar_data_type ) );

my $reserved   = q(;/?:@&=+$,[]);
my $mark       = q(-_.!~*'());                                    #'; emacs
my $unreserved = "A-Za-z0-9\Q${mark}\E";
my $uric       = quotemeta( $reserved )."${unreserved}%";

# Private functions
my $_uric_escape = sub {
    my $str = shift;

    $str =~ s{([^$uric\#])}{ URI::Escape::escape_char($1) }ego;
    utf8::downgrade( $str );
    return \$str;
};

# Public functions
sub enumerated_data_type ($;$) {
   return { data_type     => 'enum',
            default_value => $_[ 1 ],
            extra         => { list => $_[ 0 ] },
            is_enum       => TRUE, };
}

sub env_var ($;$) {
   defined $_[ 1 ] or return $ENV{ 'MCP_'.$_[ 0 ] };

   return $ENV{ 'MCP_'.$_[ 0 ] } = $_[ 1 ];
}

sub extract_lang ($) {
   return $_[ 0 ] ? (split_on__ $_[ 0 ])[ 0 ] : LANG;
}

sub foreign_key_data_type (;$$) {
   my $type_info = { data_type     => 'integer',
                     default_value => $_[ 0 ],
                     extra         => { unsigned => TRUE },
                     is_nullable   => FALSE,
                     is_numeric    => TRUE, };

   defined $_[ 1 ] and $type_info->{accessor} = $_[ 1 ];

   return $type_info;
}

sub get_hashed_pw ($) {
   my @parts = split m{ [\$] }mx, $_[ 0 ]; return substr $parts[ -1 ], 22;
}

sub get_salt ($) {
   my @parts = split m{ [\$] }mx, $_[ 0 ];

   $parts[ -1 ] = substr $parts[ -1 ], 0, 22;

   return join '$', @parts;
}

sub load_components ($$;$) {
   my ($search_path, $config, $args) = @_; $args //= {};

   $search_path or throw Unspecified,          [ 'search path' ];
   $config = merge_attributes {}, $config, {}, [ 'appclass', 'monikers' ];
   $config->{appclass} or throw Unspecified,   [ 'application class' ];

   if (first_char $search_path eq '+') { $search_path = substr $search_path, 1 }
   else { $search_path = $config->{appclass}."::${search_path}" }

   my $depth    = () = split m{ :: }mx, $search_path, -1; $depth += 1;
   my $finder   = Module::Pluggable::Object->new
      ( max_depth   => $depth,           min_depth => $depth,
        search_path => [ $search_path ], require   => TRUE, );
   my $monikers = $config->{monikers} // {};
   my $compos   = $args->{components}  = {};

   for my $class ($finder->plugins) {
      exists $monikers->{ $class } and defined $monikers->{ $class }
         and $args->{moniker} = $monikers->{ $class };

      my $comp  = $class->new( $args ); $compos->{ $comp->moniker } = $comp;
   }

   return $compos;
}

sub new_uri ($$) {
   return bless $_uric_escape->( $_[ 0 ] ), 'URI::'.$_[ 1 ];
}

sub nullable_foreign_key_data_type () {
   return { data_type         => 'integer',
            default_value     => undef,
            extra             => { unsigned => TRUE },
            is_nullable       => TRUE,
            is_numeric        => TRUE, };
}

sub nullable_varchar_data_type (;$$) {
   return { data_type         => 'varchar',
            default_value     => $_[ 1 ],
            is_nullable       => TRUE,
            size              => $_[ 0 ] || VARCHAR_MAX_SIZE, };
}

sub numerical_id_data_type (;$) {
   return { data_type         => 'smallint',
            default_value     => $_[ 0 ],
            is_nullable       => FALSE,
            is_numeric        => TRUE, };
}

sub qualify_job_name (;$$) {
   my ($name, $ns) = @_; $ns //= 'Main'; my $sep = '::'; $name //= 'void';

   return $name =~ m{ $sep }mx ? $name : "${ns}${sep}${name}";
}

sub serial_data_type () {
   return { data_type         => 'integer',
            default_value     => undef,
            extra             => { unsigned => TRUE },
            is_auto_increment => TRUE,
            is_nullable       => FALSE,
            is_numeric        => TRUE, };
}

sub set_on_create_datetime_data_type () {
   return { data_type         => 'datetime',
            set_on_create     => TRUE, };
}

sub terminate ($) {
   $_[ 0 ]->unwatch_signal( 'QUIT' ); $_[ 0 ]->unwatch_signal( 'TERM' );
   $_[ 0 ]->stop;
   return TRUE;
}

sub trigger_input_handler ($) {
   return $_[ 0 ] ? CORE::kill 'USR1', $_[ 0 ] : FALSE;
}

sub trigger_output_handler ($) {
   return $_[ 0 ] ? CORE::kill 'USR2', $_[ 0 ] : FALSE;
}

sub varchar_data_type (;$$) {
   return { data_type         => 'varchar',
            default_value     => $_[ 1 ] // NUL,
            is_nullable       => FALSE,
            size              => $_[ 0 ] || VARCHAR_MAX_SIZE, };
}

1;

__END__

=pod

=encoding utf8

=head1 Name

App::MCP::Functions - One-line description of the modules purpose

=head1 Synopsis

   use App::MCP::Functions;
   # Brief but working code examples

=head1 Description

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=back

=head1 Subroutines/Methods

=head2 job_type_enum

=head2 nullable_varchar_data_type

=head2 numerical_id_data_type

=head2 serial_data_type

=head2 varchar_data_type

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
