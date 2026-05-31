package App::MCP::Util;

use utf8; # -*- coding: utf-8; -*-
use strictures;
use parent 'Exporter::Tiny';

use App::MCP::Constants        qw( EXCEPTION_CLASS FALSE NUL SEPARATOR
                                   SQL_FALSE SQL_TRUE TRUE VARCHAR_MAX_SIZE );
use Crypt::Eksblowfish::Bcrypt qw( en_base64 );
use Digest                     qw( );
use Digest::MD5                qw( md5_hex );
use English                    qw( -no_match_vars );
use File::DataClass::IO        qw( io );
use HTML::Entities             qw( encode_entities );
use JSON::MaybeXS              qw( encode_json );
use Scalar::Util               qw( blessed weaken );
use Time::Duration             qw( concise duration );
use Web::Components::Util      qw( load_file dump_file );
use Unexpected::Functions      qw( throw );
use URI::Escape                qw( );
use URI::http;
use URI::https;
use DateTime;
use DateTime::Format::Human;

our @EXPORT_OK = qw( boolean_data_type concise_duration create_token
   create_totp_token distname dt_from_epoch dt_human encode_for_html
   enumerated_data_type foreign_key_data_type formpost fp get_hashed_pw
   get_salt local_config new_salt new_uri integer_data_type
   integer_id_data_type nullable_foreign_key_data_type nullable_text_data_type
   nullable_varchar_data_type redirect redirect2referer serial_data_type
   set_on_create_datetime_data_type strip_namespace terminate text_data_type
   trigger_input_handler trigger_output_handler truncate varchar_data_type );

=pod

=encoding utf8

=head1 Name

App::MCP::Util - Utility functions

=head1 Synopsis

   use App::MCP::Util qw( create_token );

=head1 Description

Utility functions

=head1 Configuration and Environment

Defines no attributes

=over 3

=cut

my $digest_cache;
my $reserved   = q(;/?:@&=+$,[]);
my $mark       = q(-_.!~*'());
my $unreserved = "A-Za-z0-9\Q${mark}\E%\#";
my $uric       = quotemeta($reserved) . '\p{isAlpha}' . $unreserved;

=back

=head1 Subroutines/Methods

Exports the following functions;

=over 3

=item C<concise_duration>

   $string = consise_duration $elapsed;

=cut

sub concise_duration ($) {
   return concise(duration($_[0]));
}

=item C<create_token>

   $token = create_token;

=cut

sub create_token () {
   return substr digest(urandom())->hexdigest, 0, 32;
}

=item C<create_totp_token>

   $token = create_totp_token;

=cut

sub create_totp_token () {
   return substr digest(urandom())->b64digest, 0, 16;
}

=item C<digest>

   $object = digest $seed;

=cut

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

=item C<distname>

   $string = distname $package;

=cut

sub distname (;$) {
   (my $v = $_[0] // NUL) =~ s{ :: }{-}gmx;

   return $v;
}

=item C<dt_from_epoch>

   $dt = dt_from_epoch $epoch, $timezone?;

=cut

sub dt_from_epoch ($;$) {
   my ($epoch, $tz) = @_;

   return DateTime->from_epoch(
      epoch => $epoch, locale => 'en_GB', time_zone => $tz // 'UTC'
   );
}

=item C<dt_human>

   $dt = dt_human $dt;

=cut

sub dt_human ($) {
   my $dt  = shift;
   my $fmt = DateTime::Format::Human->new(evening => 19, night => 23);

   $dt->set_formatter($fmt);
   return $dt;
}

=item C<encode_for_html>

   $encoded = encode_for_html $data_structure;

=cut

sub encode_for_html ($) {
   return encode_entities(encode_json(shift));
}

=item C<formpost>

   $hash_ref = formpost;

=cut

sub formpost () {
   return { method => 'post' };
}

=item C<fp>

    $fingerprint = fp $value;

=cut

sub fp ($) {
   my $v = shift;

   return length($v) . '.' . substr(md5_hex($v), 0, 4);
}

=item C<get_hashed_pw>

   $string = get_hashed_pw $encrypted_password;

=cut

sub get_hashed_pw ($) {
   my @parts = split m{ [\$] }mx, shift;

   return substr $parts[-1], 32 if $parts[1] eq '5054';

   return substr $parts[-1], 22;
}

=item C<get_salt>

   $string = get_salt $encrypted_password;

=cut

sub get_salt ($) {
   my @parts = split m{ [\$] }mx, shift;

   return substr $parts[-1], 0, 32 if $parts[1] eq '5054';

   $parts[-1] = substr $parts[-1], 0, 22;

   return join '$', @parts;
}

=item C<local_config>

   $hash_ref = local_config($config, \%data?);

=cut

sub local_config ($;$) {
   my ($config, $data) = @_;

   throw 'Local config file undefined' unless $config->has_local_config_file;

   my $file = $config->local_config_file;
   my $path = $file->exists ? $file : $config->config_home->child("${file}");

   if ($data) {
      dump_file($path->assert, $data);
      return $data;
   }

   return load_file($path, TRUE) // {} if $path->exists;

   return {};
}

=item C<new_salt>

   $string = new_salt $type, $load_factor;

=cut

sub new_salt ($$) {
   my ($type, $lf) = @_;

   return create_token if $type eq '5054';

   return "\$${type}\$${lf}\$" . en_base64(pack('H*', create_token));
}

=item C<new_uri>

   $object = new_uri $scheme, $path_info;

=cut

sub new_uri ($$) {
   my $v = uri_escape($_[1]);

   return bless \$v, 'URI::'.$_[0];
}

=item C<redirect>

   $key_value = redirect $location, $message, \%options?;

=cut

sub redirect ($$;$) {
   return redirect => { %{$_[2] // {}}, location => $_[0], message => $_[1] };
}

=item C<redirect2referer>

   $key_value = redirect2referer $context, $message?;

=cut

sub redirect2referer ($;$) {
   my ($context, $message) = @_;

   my $referer = new_uri 'http', $context->request->referer;

   return redirect $referer, $message;
}

=item C<strip_namespace>

   $stripped = strip_namespace $job_name;

=cut

sub strip_namespace ($) {
   my $v   = shift // q();
   my $sep = SEPARATOR;

   $v = (split m{ $sep }mx, $v)[-1] if $v =~ m{ $sep }mx;

   return $v;
}

=item C<terminate>

   $true = terminate $async_object_ref;

=cut

sub terminate ($) {
   $_[0]->unwatch_signal('QUIT');
   $_[0]->unwatch_signal('TERM');
   $_[0]->stop;
   return TRUE;
}

=item C<trigger_input_handler>

   $bool = trigger_input_handler $pid;

=cut

sub trigger_input_handler ($) {
   my $arg = shift;
   my $pid;

   if (blessed $arg) { $pid = _read_pid_file($arg) }
   else { $pid = $arg }

   return unless $pid;

   return CORE::kill 'USR1', $pid;
}

=item C<trigger_output_handler>

   $bool = trigger_output_handler $pid;

=cut

sub trigger_output_handler ($) {
   my $arg = shift;
   my $pid;

   if (blessed $arg) { $pid = _read_pid_file($arg) }
   else { $pid = $arg }

   return unless $pid;

   return CORE::kill 'USR2', $pid;
}

=item C<truncate>

   $string = truncate $string, $length?;

=cut

sub truncate ($;$) {
   my ($string, $length) = @_;

   $length //= 80;
   return substr($string, 0, $length - 1) . '…';
}

=item C<urandom>

   $bytes = urandom $wanted?, \%options?;

=cut

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

=item C<uri_escape>

   $escaped = uri_escape $uri, $pattern?;

=cut

sub uri_escape ($;$) {
   my ($v, $pattern) = @_;

   $pattern //= $uric;
   $v =~ s{([^$pattern])}{ URI::Escape::uri_escape_utf8($1) }ego;
   utf8::downgrade($v);
   return $v;
}

=back

=head1 Data Types

Exports the following data types;

=over 3

=item C<boolean_data_type>

=cut

sub boolean_data_type (;$) {
   return {
      cell_traits   => ['Bool'],
      data_type     => 'boolean',
      default_value => $_[0] ? SQL_TRUE : SQL_FALSE,
      is_nullable   => FALSE,
   };
}

=item C<enumerated_data_type>

=cut

sub enumerated_data_type ($;$) {
   return {
      data_type     => 'enum',
      default_value => $_[1],
      extra         => { list => $_[0] },
      is_enum       => TRUE,
   };
}

=item C<foreign_key_data_type>

=cut

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

=item C<nullable_foreign_key_data_type>

=cut

sub nullable_foreign_key_data_type () {
   return {
      data_type   => 'integer',
      extra       => { unsigned => TRUE },
      is_nullable => TRUE,
      is_numeric  => TRUE,
   };
}

=item C<integer_data_type>

=cut

sub integer_data_type (;$) {
   return {
      data_type     => 'integer',
      default_value => $_[0],
      is_nullable   => FALSE,
      is_numeric    => TRUE,
   };
}

=item C<integer_id_data_type>

=cut

sub integer_id_data_type (;$) {
   return {
      data_type     => 'smallint',
      default_value => $_[0],
      is_nullable   => FALSE,
      is_numeric    => TRUE,
   };
}

=item C<serial_data_type>

=cut

sub serial_data_type () {
   return {
      data_type         => 'integer',
      extra             => { unsigned => TRUE },
      is_auto_increment => TRUE,
      is_nullable       => FALSE,
      is_numeric        => TRUE,
   };
}

=item C<set_on_create_datetime_data_type>

=cut

sub set_on_create_datetime_data_type () {
   return {
      data_type     => 'datetime',
      cell_traits   => ['DateTime'],
      set_on_create => TRUE,
      timezone      => 'UTC',
   };
}

=item C<text_data_type>

=cut

sub text_data_type (;$) {
   return {
      data_type     => 'text',
      default_value => $_[0],
      is_nullable   => FALSE,
   };
}

=item C<nullable_text_data_type>

=cut

sub nullable_text_data_type (;$) {
   return {
      data_type     => 'text',
      default_value => $_[0],
      is_nullable   => TRUE,
   };
}

=item C<varchar_data_type>

=cut

sub varchar_data_type (;$$) {
   return {
      data_type     => 'varchar',
      default_value => $_[1],
      is_nullable   => FALSE,
      size          => $_[0] || VARCHAR_MAX_SIZE,
   };
}

=item C<nullable_varchar_data_type>

=cut

sub nullable_varchar_data_type (;$$) {
   return {
      data_type     => 'varchar',
      default_value => $_[1],
      is_nullable   => TRUE,
      size          => $_[0] || VARCHAR_MAX_SIZE,
   };
}

# Private methods
sub _pseudo_random {
   return join q(), time, rand 10_000, $PID, {};
}

sub _read_pid_file {
   my $config  = shift;
   my $name    = lc distname $config->appclass;
   my $pidfile = $config->rundir->catfile("${name}.pid");

   return FALSE unless $pidfile->exists;

   return $pidfile->chomp->getline;
}

1;

__END__

=back

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Crypt::Eksblowfish::Bcrypt>

=item L<Digest>

=item L<Exporter::Tiny>

=item L<File::DataClass::IO>

=item L<HTML::Entities>

=item L<JSON::MaybeXS>

=item L<Time::Duration>

=item L<URI>

=item L<DateTime>

=item L<DateTime::Format::Human>

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

Copyright (c) 2025 Peter Flanigan. All rights reserved

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
