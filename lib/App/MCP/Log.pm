package App::MCP::Log;

use Class::Usul::Cmd::Constants qw( DOT FALSE NUL TRUE USERNAME );
use Class::Usul::Cmd::Types     qw( Bool ConfigProvider );
use Class::Usul::Cmd::Util      qw( now_dt trim );
use HTML::StateTable::Util      qw( escape_formula );
use Ref::Util                   qw( is_arrayref is_coderef );
use Moo;

with 'App::MCP::Role::CSVParser';

has 'config' => is => 'ro', isa => ConfigProvider, required => TRUE;

has '_debug' =>
   is       => 'lazy',
   isa      => Bool,
   init_arg => 'debug',
   default  => sub {
      my $self  = shift;
      my $debug = $self->config->appclass->env_var('debug');

      return defined $debug ? !!$debug : FALSE;
   };

around 'BUILDARGS' => sub {
   my ($orig, $self, @args) = @_;

   my $attr = $orig->($self, @args);

   if (my $builder = delete $attr->{builder}) {
      $attr->{config} //= $builder->config;
      $attr->{debug} //= $builder->debug;
   }

   return $attr;
};

sub alert {
   return shift->_log('ALERT', NUL, @_);
}

sub debug {
   my $self = shift;

   return unless $self->_debug;

   return $self->_log('DEBUG', NUL, @_);
}

sub error {
   return shift->_log('ERROR', NUL, @_);
}

sub fatal {
   return shift->_log('FATAL', NUL, @_);
}

sub info {
   return shift->_log('INFO', NUL, @_);
}

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

sub warn {
   return shift->_log('WARNING', NUL, @_);
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

   return (trim($leader), trim($message));
}

sub _log {
   my ($self, $level, $leader, $message, $context) = @_;

   $level   ||= 'ERROR';
   $message ||= 'Unknown';
   $message = "${message}";
   chomp $message;
   $message =~ s{ \n }{. }gmx;

   ($leader, $message) = $self->_get_leader($message, $context) unless $leader;

   my $now      = now_dt->strftime('%Y/%m/%d %T');
   my $username = $context && $context->can('session')
      ? $context->session->username : USERNAME;

   $self->csv_parser->combine(
      escape_formula $now, $level, $username, $leader, $message
   );

   my $config = $self->config;

   if ($config->can('logfile') && $config->logfile) {
      $config->logfile->appendln($self->csv_parser->string)->flush;
   }
   else { CORE::warn "${leader}: ${message}\n" }

   return TRUE;
}

use namespace::autoclean;

1;

__END__

=pod

=encoding utf-8

=head1 Name

App::MCP::Log - Master Control Program - Dependency and time based job scheduler

=head1 Synopsis

   use App::MCP::Log;
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

Copyright (c) 2024 Peter Flanigan. All rights reserved

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
