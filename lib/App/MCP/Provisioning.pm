package App::MCP::Provisioning;

use version;

use App::MCP::Constants     qw( FALSE TRUE );
use Class::Usul::Cmd::Types qw( ConfigProvider HashRef Logger Str );
use App::MCP::Util          qw( distname );
use Moo;

=pod

=encoding utf-8

=head1 Name

App::MCP::Provisioning - Master Control Program - Provision remote workers


=head1 Synopsis

   use App::MCP::Provisioning;

=head1 Description

Provision remote workers

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=item C<config>

=cut

has 'config' => is => 'ro', isa => ConfigProvider, required => TRUE;

=item C<log>

=cut

has 'log' => is => 'ro', isa => Logger, required => TRUE;

=item C<worker>

=cut

has 'worker' =>
   is      => 'lazy',
   isa     => Str,
   default => sub { shift->config->appclass . '::Worker' };

has '_provisioned'  => is => 'ro', isa => HashRef, default => sub { {} };

=back

=head1 Subroutines/Methods

Defineds the following methods;

=over 3

=item C<add_provisioning>

   $self->add_provisioning(\%args);

=cut

sub add_provisioning {
   my ($self, $args) = @_;

   my $host = $args->{host};
   my $user = $args->{user};

   return unless $host && $user;
   return if $self->remote_provisioned("${user}\@${host}");

   my $calls    = $args->{calls};
   my $appclass = $self->config->appclass;
   my $worker   = $self->worker;

   unshift @{$calls}, ['provision', [$appclass, $worker], 'install_worker'];
   return;
}

=item C<install_worker>

   $self->install_worker($leader, $call, \%args, $response, \%results);

=cut

sub install_worker {
   my ($self, $leader, $call, $args, $response, $results) = @_;

   my $dist      = distname $self->worker;
   my $share     = $self->config->sharedir;
   my $filter    = qr{ \b $dist - ([0-9\.]+) \.tar\.gz \z }mx;
   my $our_ver   = (sort map { $_ =~ $filter; qv($1) } map { $_->basename }
                    $share->filter(sub { $_ =~ $filter })->all_files)[-1];
   my ($rem_ver) = $response =~ m{ \A version= (.+) \z }mx;
   my $key       = $args->{user} . '@' . $args->{host};

   $our_ver //= qv('0.0.0');
   $rem_ver = qv($rem_ver // '0.0.0');
   $self->log->debug("${leader}: Worker current - ${key} ${rem_ver}");

   if ($rem_ver >= $our_ver) {
      $results->{provisioned} = { key => $key, value => "${rem_ver}" };
      return;
   }

   my $file    = "${dist}-${our_ver}.tar.gz";
   my $tarball = $share->catfile($file);

   return $self->log->error("${leader}: File ${tarball} not found")
      unless $tarball->exists;

   $self->log->debug("${leader}: Worker upgrade - ${rem_ver} to ${our_ver}");
   unshift @{$args->{calls}}, ['distclean', [$self->config->appclass]];

   # TODO: Need to force reload of worker after upgrade
   $self->_install_distribution($args->{calls}, $file);
   $self->_install_distribution($args->{calls}, 'local::lib');
   $self->_install_cpan_minus  ($args->{calls}, 'App-cpanminus.tar.gz');
   return;
}

=item C<remote_provisioned>

   $value = $self->remote_provisioned($key, $value);

Accessor/mutator

=cut

sub remote_provisioned {
   my ($self, $key, $val) = @_;

   $self->_provisioned->{$key} = $val if defined $val;

   return $self->_provisioned->{$key};
}

# Private methods
sub _install_cpan_minus {
   return shift->_install_remote('install_cpan_minus', @_);
}

sub _install_distribution {
   return shift->_install_remote('install_distribution', @_);
}

sub _install_remote {
   my ($self, $method, $calls, $file) = @_;

   my $config   = $self->config;
   my $appclass = $config->appclass;

   unshift @{$calls}, [$method, [$appclass, $file]];

   return if $file =~ m{ \A [a-zA-Z0-9_]+ : }mx;

   my $path = $config->sharedir->catfile($file);

   unshift @{$calls}, ['writefile', [$appclass, $file, $path->all]];
   return;
}

use namespace::autoclean;

1;

__END__

=back

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Moo>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module. Please report problems to
http://rt.cpan.org/NoAuth/Bugs.html?Dist=App-MCP.  Patches are welcome

=head1 Acknowledgements

Larry Wall - For the Perl programming language

=head1 Author

Peter Flanigan, C<< <pjfl@cpan.org> >>

=head1 License and Copyright

Copyright (c) 2026 Peter Flanigan. All rights reserved

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
