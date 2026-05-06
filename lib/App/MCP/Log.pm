package App::MCP::Log;

use Class::Usul::Cmd::Constants qw( DOT FALSE NUL TRUE USERNAME );
use Class::Usul::Cmd::Types     qw( Bool ConfigProvider );
use Class::Usul::Cmd::Util      qw( now_dt trim );
use HTML::StateTable::Util      qw( escape_formula );
use Ref::Util                   qw( is_arrayref is_coderef );
use Scalar::Util                qw( blessed );
use English                     qw( -no_match_vars );
use Moo;

with 'App::MCP::Role::CSVParser';

=pod

=encoding utf-8

=head1 Name

App::MCP::Log - Logging class

=head1 Synopsis

   use App::MCP::Log;

=head1 Description

Logs messages in CSV format to the specified logfile

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=item C<config>

A required reference to the L<configuration|App::MCP::Config> object

=cut

has 'config' => is => 'ro', isa => ConfigProvider, required => TRUE;

=item C<logfile>

L<File object|File::DataClass::IO> for the log file. Provided by the C<config>
object. If undefined then will warn to C<stderr> instead

=cut

has 'logfile' =>
   is      => 'lazy',
   default => sub {
      my $config = shift->config;

      return $config->logfile if $config->can('logfile') && $config->logfile;

      return;
   };

has '_debug' =>
   is       => 'lazy',
   isa      => Bool,
   init_arg => 'debug',
   default  => sub {
      my $self  = shift;
      my $debug = $self->config->appclass->env_var('debug');

      return defined $debug ? !!$debug : FALSE;
   };

=back

=head1 Subroutines/Methods

Defines the following methods;

=over 3

=item C<BUILDARGS>

Sets C<config> and C<debug> from the C<builder> attribute

=cut

around 'BUILDARGS' => sub {
   my ($orig, $self, @args) = @_;

   my $attr = $orig->($self, @args);

   if (my $builder = $attr->{builder}) {
      $attr->{config} = $builder->config;
      $attr->{debug}  = $builder->debug;
   }

   return $attr;
};

=item C<alert>

   $true = $self->alert($message, $context?);

Logs C<message> at the C<alert> level

Attributes of the C<context> object are;

=over 3

=item C<leader>

=item C<action>

=item C<name>

=back

The first of these with a value will be used as the leader for the log message

=cut

sub alert {
   return shift->_log('ALERT', NUL, @_);
}

=item C<debug>

   $true = $self->debug($message, $context?);

Logs C<message> at the C<debug> level iff debug is enabled. Debug is enabled by
setting the environment variable C<APP_MCP_DEBUG> to true

=cut

sub debug {
   my $self = shift;

   return unless $self->_debug;

   return $self->_log('DEBUG', NUL, @_);
}

=item C<error>

   $true = $self->error($message, $context?);

Logs C<message> at the C<error> level

=cut

sub error {
   return shift->_log('ERROR', NUL, @_);
}

=item C<fatal>

   $true = $self->fatal($message, $context?);

Logs C<message> at the C<fatal> level

=cut

sub fatal {
   return shift->_log('FATAL', NUL, @_);
}

=item C<info>

    $true = $self->info($message, $context?);

Logs C<message> at the C<info> level

=cut

sub info {
   return shift->_log('INFO', NUL, @_);
}

=item C<warn>

    $true = $self->warn($message, $context?);

Logs C<message> at the C<warn> level

=cut

sub warn {
   return shift->_log('WARNING', NUL, @_);
}

=item C<log>

   $true = $self->log(%args);

For the benefit of L<Plack::Middleware::LogDispatch>

=cut

sub log { # For benefit of P::M::LogDispatch
   my ($self, %args) = @_;

   my $level   = uc $args{level};
   my $message = $args{message};
   my $leader  = $args{name} || (split m{ :: }mx, caller)[-1];

   return if $level =~ m{ debug }imx && !$self->_debug;

   $message = $message->() if is_coderef $message;
   $message = is_arrayref $message ? $message->[0] : $message;

   return $self->_log($level, $leader, $message);
}

# Private methods
sub _get_leader {
   my ($self, $message, $context) = @_;

   my $leader;

   if ($context) {
      if ($context->can('leader')) { $leader = $context->leader }
      elsif ($context->can('action') && $context->has_action) {
         my @parts = split m{ / }mx, ucfirst $context->action;

         $leader = $parts[0] . DOT . $parts[-1];
      }
      elsif ($context->can('name')) { $leader = ucfirst $context->name }
   }

   unless ($leader) {
      if ($message =~ m{ \A [^:]+ : }mx) {
         ($leader, $message) = split m{ : }mx, $message, 2;
      }
      else { $leader = 'Unknown' }
   }

   $leader = "${leader}[${PID}]" unless $leader =~ m{ \[ .+ \] }mx;

   return (trim($leader), trim($message));
}

sub _log {
   my ($self, $level, $leader, $message, $context) = @_;

   my $config = $self->config;

   if (blessed $message && $message->isa($config->context_class)) {
      $context = $message;
      $message = 'No message supplied';
   }

   $level   ||= 'ERROR';
   $message ||= 'Unknown';
   $message = "${message}";
   chomp $message;
   $message =~ s{ \n }{. }gmx;

   ($leader, $message) = $self->_get_leader($message, $context) unless $leader;

   if ($config->can('log_message_maxlen') && $config->log_message_maxlen) {
      my $max = $config->log_message_maxlen;

      $message = (substr $message, 0, $max) . '...' if length $message > $max;
   }

   if ($self->logfile) {
      my $now      = now_dt->strftime('%Y/%m/%d %T');
      my $username = $context && $context->can('session')
         ? $context->session->username : USERNAME;
      my @fields   = ($now, $level, $username, $leader, $message);

      $self->csv_parser->combine(escape_formula @fields);
      $self->logfile->appendln($self->csv_parser->string)->flush;
   }
   else { CORE::warn "${leader}: ${message}\n" }

   return TRUE;
}

use namespace::autoclean;

1;

__END__

=back

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<App::MCP::Role::CSVParser>

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
# vim: expandtab shiftwidth=3:
