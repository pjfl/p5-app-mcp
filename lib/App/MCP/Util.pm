package App::MCP::Util;

use utf8; # -*- coding: utf-8; -*-
use strictures;
use parent 'Exporter::Tiny';

use App::MCP::Constants        qw( FALSE NUL SEPARATOR SQL_FALSE SQL_TRUE TRUE
                                   VARCHAR_MAX_SIZE );
use Class::Usul::Functions     qw( class2appdir find_apphome
                                   get_cfgfiles is_member );
use Class::Usul::Time          qw( str2time time2str );
use Crypt::Eksblowfish::Bcrypt qw( en_base64 );
use Digest                     qw( );
use English                    qw( -no_match_vars );
use File::DataClass::IO        qw( io );
use Scalar::Util               qw( weaken );
use URI::Escape                qw( );
use URI::http;
use URI::https;

our @EXPORT_OK = qw( base64_decode base64_encode boolean_data_type
   clear_redirect create_token enumerated_data_type enhance
   foreign_key_data_type formpost get_hashed_pw get_salt new_salt new_uri
   nullable_foreign_key_data_type nullable_varchar_data_type
   numerical_id_data_type random_digest redirect redirect2referer
   serial_data_type set_on_create_datetime_data_type stash_functions
   strip_parent_name terminate text_data_type trigger_input_handler
   trigger_output_handler truncate varchar_data_type );

my $digest_cache;
my $reserved   = q(;/?:@&=+$,[]);
my $mark       = q(-_.!~*'());                                   #'; emacs
my $unreserved = "A-Za-z0-9\Q${mark}\E%\#";
my $uric       = quotemeta($reserved) . '\p{isAlpha}' . $unreserved;

# Public functions
my $base64_char_set = sub { [ 0 .. 9, 'A' .. 'Z', '_', 'a' .. 'z', '~', '+' ] };
my $index64 = sub { [
   qw(XX XX XX XX  XX XX XX XX  XX XX XX XX  XX XX XX XX
      XX XX XX XX  XX XX XX XX  XX XX XX XX  XX XX XX XX
      XX XX XX XX  XX XX XX XX  XX XX XX 64  XX XX XX XX
       0  1  2  3   4  5  6  7   8  9 XX XX  XX XX XX XX
      XX 10 11 12  13 14 15 16  17 18 19 20  21 22 23 24
      25 26 27 28  29 30 31 32  33 34 35 XX  XX XX XX 36
      XX 37 38 39  40 41 42 43  44 45 46 47  48 49 50 51
      52 53 54 55  56 57 58 59  60 61 62 XX  XX XX 63 XX

      XX XX XX XX  XX XX XX XX  XX XX XX XX  XX XX XX XX
      XX XX XX XX  XX XX XX XX  XX XX XX XX  XX XX XX XX
      XX XX XX XX  XX XX XX XX  XX XX XX XX  XX XX XX XX
      XX XX XX XX  XX XX XX XX  XX XX XX XX  XX XX XX XX
      XX XX XX XX  XX XX XX XX  XX XX XX XX  XX XX XX XX
      XX XX XX XX  XX XX XX XX  XX XX XX XX  XX XX XX XX
      XX XX XX XX  XX XX XX XX  XX XX XX XX  XX XX XX XX
      XX XX XX XX  XX XX XX XX  XX XX XX XX  XX XX XX XX)
]};

sub base64_decode ($) {
   my $x = shift;

   return unless defined $x;

   my @x = split q(), $x;
   my $index = $index64->();
   my $j = 0;
   my $k = 0;
   my $len = length $x;
   my $pad = 64;
   my @y = ();

 ROUND: {
    while ($j < $len) {
       my @c = ();
       my $i = 0;

       while ($i < 4) {
          my $uc = $index->[ord $x[$j++]];

          $c[$i++] = 0 + $uc if $uc ne 'XX';
          next unless $j == $len;

          if ($i < 4) {
             last ROUND if $i < 2;
             $c[2] = $pad if $i == 2;
             $c[3] = $pad;
          }

          last;
       }

       last if $c[0] == $pad or $c[1] == $pad;
       $y[$k++] = ( $c[0] << 2) | (($c[1] & 0x30) >> 4);
       last if $c[2] == $pad;
       $y[$k++] = (($c[1] & 0x0F) << 4) | (($c[2] & 0x3C) >> 2);
       last if $c[3] == $pad;
       $y[$k++] = (($c[2] & 0x03) << 6) | $c[3];
    }
 }

   return join q(), map { chr $_ } @y;
}

sub base64_encode (;$) {
   my $x = shift;

   return unless defined $x;

   my @x = split q(), $x;
   my $basis = $base64_char_set->();
   my $len = length $x;
   my @y = ();

   for (my $i = 0, my $j = 0; $len > 0; $len -= 3, $i += 3) {
      my $c1 = ord $x[$i];
      my $c2 = $len > 1 ? ord $x[$i + 1] : 0;

      $y[$j++] = $basis->[$c1 >> 2];
      $y[$j++] = $basis->[(($c1 & 0x3) << 4) | (($c2 & 0xF0) >> 4)];

      if ($len > 2) {
         my $c3 = ord $x[$i + 2];

         $y[$j++] = $basis->[(($c2 & 0xF) << 2) | (($c3 & 0xC0) >> 6)];
         $y[$j++] = $basis->[$c3 & 0x3F];
      }
      elsif ($len == 2) {
         $y[$j++] = $basis->[($c2 & 0xF) << 2];
         $y[$j++] = $basis->[64];
      }
      else { # len == 1
         $y[$j++] = $basis->[64];
         $y[$j++] = $basis->[64];
      }
   }

   return join q(), @y;
}

sub boolean_data_type {
   return {
      cell_traits   => ['Bool'],
      data_type     => 'boolean',
      default_value => $_[0] ? SQL_TRUE : SQL_FALSE,
      is_nullable   => FALSE,
   };
}

sub clear_redirect ($) {
   return delete shift->stash->{redirect};
}

sub create_token () {
   return substr random_digest()->hexdigest, 0, 32;
}

sub digest ($) {
   my $seed = shift;

   my ($candidate, $digest);

   if ($digest_cache) { $digest = Digest->new($digest_cache) }
   else {
      for (qw( SHA-512 SHA-256 SHA-1 MD5 )) {
         $candidate = $_;
         last if $digest = eval { Digest->new($candidate) };
      }

      die 'Digest algorithm not found' unless $digest;
      $digest_cache = $candidate;
   }

   $digest->add($seed);

   return $digest;
}

sub enumerated_data_type ($;$) {
   return {
      data_type     => 'enum',
      default_value => $_[1],
      extra         => { list => $_[0] },
      is_enum       => TRUE,
   };
}

sub enhance ($) {
   my $conf = shift;
   my $attr = { config => { %{ $conf } }, }; $conf = $attr->{config};

   $conf->{appclass    } //= 'App::MCP';
   $attr->{config_class} //= $conf->{appclass}.'::Config';
   $conf->{name        } //= class2appdir $conf->{appclass};
   $conf->{home        } //= find_apphome $conf->{appclass}, $conf->{home};
   $conf->{cfgfiles    } //= get_cfgfiles $conf->{appclass}, $conf->{home};

   return $attr;
}

sub foreign_key_data_type (;$$) {
   my $type_info = {
      data_type     => 'integer',
      default_value => $_[0],
      extra         => { unsigned => TRUE },
      is_nullable   => FALSE,
      is_numeric    => TRUE,
   };

   $type_info->{accessor} = $_[1] if defined $_[1];

   return $type_info;
}

sub formpost () {
   return { method => 'post' };
}

sub get_hashed_pw ($) {
   my @parts = split m{ [\$] }mx, $_[0];

   return substr $parts[-1], 22;
}

sub get_salt ($) {
   my @parts = split m{ [\$] }mx, $_[0];

   $parts[-1] = substr $parts[-1], 0, 22;

   return join '$', @parts;
}

sub new_salt ($$) {
   my ($type, $lf) = @_;

   return "\$${type}\$${lf}\$" . (en_base64(pack('H*', create_token)));
}

sub new_uri ($$) {
   my $v = uri_escape($_[1]); return bless \$v, 'URI::'.$_[0];
}

sub nullable_foreign_key_data_type () {
   return {
      data_type   => 'integer',
      extra       => { unsigned => TRUE },
      is_nullable => TRUE,
      is_numeric  => TRUE,
   };
}

sub nullable_varchar_data_type (;$$) {
   return {
      data_type     => 'varchar',
      default_value => $_[1],
      is_nullable   => TRUE,
      size          => $_[0] || VARCHAR_MAX_SIZE,
   };
}

sub numerical_id_data_type (;$) {
   return {
      data_type     => 'smallint',
      default_value => $_[0],
      is_nullable   => FALSE,
      is_numeric    => TRUE,
   };
}

sub random_digest () {
   return digest(urandom());
}

sub redirect ($$;$) {
   return redirect => { %{$_[2] // {}}, location => $_[0], message => $_[1] };
}

sub redirect2referer ($;$) {
   my ($context, $message) = @_;

   my $referer = new_uri 'http', $context->request->referer;

   return redirect $referer, $message;
}

sub serial_data_type () {
   return {
      data_type         => 'integer',
      extra             => { unsigned => TRUE },
      is_auto_increment => TRUE,
      is_nullable       => FALSE,
      is_numeric        => TRUE,
   };
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

sub text_data_type (;$) {
   return {
      data_type     => 'text',
      default_value => $_[0],
      is_nullable   => FALSE,
   };
}

sub trigger_input_handler ($) {
   return $_[ 0 ] ? CORE::kill 'USR1', $_[ 0 ] : FALSE;
}

sub trigger_output_handler ($) {
   return $_[ 0 ] ? CORE::kill 'USR2', $_[ 0 ] : FALSE;
}

sub truncate ($;$) {
   my ($string, $length) = @_;

   $length //= 80;
   return substr($string, 0, $length - 1) . '…';
}

sub urandom (;$$) {
   my ($wanted, $opts) = @_;

   $wanted //= 64; $opts //= {};

   my $default = [q(), 'dev', $OSNAME eq 'freebsd' ? 'random' : 'urandom'];
   my $io      = io($opts->{source} // $default)->block_size($wanted);

   if ($io->exists and $io->is_readable and my $red = $io->read) {
      return ${ $io->buffer } if $red == $wanted;
   }

   my $res = q();

   while (length $res < $wanted) { $res .= _pseudo_random() }

   return substr $res, 0, $wanted;
}

sub uri_escape ($;$) {
   my ($v, $pattern) = @_; $pattern //= $uric;

   $v =~ s{([^$pattern])}{ URI::Escape::uri_escape_utf8($1) }ego;
   utf8::downgrade( $v );
   return $v;
}

sub varchar_data_type (;$$) {
   return {
      data_type     => 'varchar',
      default_value => $_[1],
      is_nullable   => FALSE,
      size          => $_[0] || VARCHAR_MAX_SIZE,
   };
}

# Private methods
sub _pseudo_random {
   return join q(), time, rand 10_000, $PID, {};
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
