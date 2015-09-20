package App::MCP::Util;

use strictures;
use parent 'Exporter::Tiny';

use App::MCP::Constants    qw( FALSE NUL SEPARATOR TRUE VARCHAR_MAX_SIZE );
use Class::Usul::Functions qw( find_apphome get_cfgfiles is_member );
use Class::Usul::Time      qw( str2time time2str );
use Scalar::Util           qw( weaken );

our @EXPORT_OK = qw( enumerated_data_type enhance foreign_key_data_type
                     get_hashed_pw get_salt nullable_foreign_key_data_type
                     nullable_varchar_data_type numerical_id_data_type
                     serial_data_type set_on_create_datetime_data_type
                     stash_functions strip_parent_name terminate
                     trigger_input_handler trigger_output_handler
                     varchar_data_type );

# Public functions
sub enumerated_data_type ($;$) {
   return { data_type     => 'enum',
            default_value => $_[ 1 ],
            extra         => { list => $_[ 0 ] },
            is_enum       => TRUE, };
}

sub enhance ($) {
   my $conf = shift;
   my $attr = { config => { %{ $conf } }, }; $conf = $attr->{config};

   $conf->{appclass    } //= 'App::MCP';
   $attr->{config_class} //= $conf->{appclass}.'::Config';
   $conf->{name        } //= 'listener'; #TODO: app_prefix   $conf->{appclass};
   $conf->{home        } //= find_apphome $conf->{appclass}, $conf->{home};
   $conf->{cfgfiles    } //= get_cfgfiles $conf->{appclass}, $conf->{home};

   return $attr;
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

sub stash_functions ($$$) {
   my ($app, $src, $dest) = @_; weaken $src;

   $dest->{is_member} = \&is_member;
   $dest->{loc      } = sub { $src->loc( @_ ) };
   $dest->{str2time } = \&str2time;
   $dest->{time2str } = \&time2str;
   $dest->{ucfirst  } = sub { ucfirst $_[ 0 ] };
   $dest->{uri_for  } = sub { $src->uri_for( @_ ), };
   return;
}

sub strip_parent_name ($) {
   my $v = shift; my $sep = SEPARATOR; my @values;

   $v =~ m{ $sep }mx and @values = split m{ $sep }mx, $v and $v = pop @values;

   return $v;
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

App::MCP::Util - One-line description of the modules purpose

=head1 Synopsis

   use App::MCP::Util;

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
