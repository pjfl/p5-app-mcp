package App::MCP::Context;

use attributes ();

use App::MCP::Constants     qw( EXCEPTION_CLASS FALSE NUL TRUE );
use Class::Usul::Cmd::Types qw( ConfigProvider Int Str );
use HTML::Forms::Util       qw( get_token verify_token );
use Ref::Util               qw( is_arrayref is_coderef is_hashref );
use Scalar::Util            qw( blessed );
use Type::Utils             qw( class_type );
use Unexpected::Functions   qw( throw NoMethod UnknownModel );
use App::MCP::Response;
use Moo;

extends 'Web::Components::Context';

has 'config' => is => 'ro', isa => ConfigProvider, required => TRUE;

has 'icons_uri' =>
   is      => 'lazy',
   isa     => class_type('URI'),
   default => sub {
      my $self = shift;

      return $self->request->uri_for($self->config->icons);
   };

has 'response' =>
   is      => 'lazy',
   isa     => class_type('App::MCP::Response'),
   default => sub { App::MCP::Response->new };

has 'time_zone' =>
   is      => 'lazy',
   isa     => Str,
   default => sub { shift->session->timezone };

has 'token_lifetime' =>
   is      => 'lazy',
   isa     => Int,
   default => sub { shift->config->token_lifetime };

has '+_stash' =>
   default => sub {
      my $self   = shift;
      my $prefix = $self->config->prefix;
      my $skin   = $self->session->skin || $self->config->skin;

      return {
         chartlibrary       => 'js/highcharts.js',
         favicon            => 'img/favicon.ico',
         features           => $self->session->features,
         javascript         => "js/${prefix}.js",
         session_updated    => $self->session->updated,
         skin               => $skin,
         stylesheet         => "css/${prefix}-${skin}.css",
         theme              => $self->session->theme,
         verification_token => $self->verification_token,
         version            => App::MCP->VERSION
      };
   };

with 'App::MCP::Role::Schema';
with 'App::MCP::Role::Authentication';

sub get_attributes {
   my ($self, $action) = @_;

   return unless $action;

   return attributes::get($action) // {} if is_coderef $action;

   my ($moniker, $method) = split m{ / }mx, $action;

   return {} unless $moniker && $method;

   my $component = $self->models->{$moniker}
      or throw UnknownModel, [$moniker];
   my $coderef = $component->can($method)
      or throw NoMethod, [blessed $component, $method];

   return attributes::get($coderef) // {};
}

sub method_chain {
   my ($self, $action) = @_;

   return $self->_action_path2methods($action);
}

sub model {
   my ($self, $rs_name) = @_;

   return $rs_name ? $self->schema->resultset($rs_name) : undef;
}

sub res { shift->response }

sub uri_for_action {
   my ($self, $action, $args, @params) = @_;

   my $uri    = $self->_action_path2uri($action) // $action;
   my $uris   = is_arrayref $uri ? $uri : [ $uri ];
   my $params = is_hashref $params[0] ? $params[0] : {@params};

   for my $candidate (@{$uris}) {
      my $n_stars =()= $candidate =~ m{ \* }gmx;

      if ($n_stars == 2 and $candidate =~ m{ / \* \* }mx) {
         ($uri = $candidate) =~ s{ / \* \* }{}mx;
         last;
      }

      if ($n_stars == 2 and $candidate =~ m{ / \* \. \* }mx) {
         ($uri = $candidate) =~ s{ / \* \. \* }{}mx;
         last;
      }

      next if $n_stars != 0 and $n_stars > scalar @{$args // []};

      $uri = $candidate;

      while ($uri =~ m{ \* }mx) {
         my $arg = shift @{$args // []};

         last unless defined $arg;

         $uri =~ s{ \* }{$arg}mx;
      }

      last;
   }

   $uri .= delete $params->{extension} if exists $params->{extension};

   return $self->request->uri_for($uri, $args, $params);
}

sub verification_token {
   my $self = shift;

   return get_token $self->token_lifetime, $self->session->serialise;
}

sub verify_form_post {
   my $self  = shift;
   my $token = $self->body_parameters->{_verify} // NUL;

   return verify_token $token, $self->session->serialise;
}

# Private methods
sub _action_path2methods {
   my ($self, $action) = @_;

   for my $controller (keys %{$self->controllers}) {
      my $map = $self->controllers->{$controller}->action_path_map;

      return $map->{$action}->{methods} if exists $map->{$action};
   }

   return 'misc/root/not_found';
}

sub _action_path2uri {
   my ($self, $action) = @_;

   for my $controller (keys %{$self->controllers}) {
      my $map = $self->controllers->{$controller}->action_path_map;

      return $map->{$action}->{uri} if exists $map->{$action};
   }

   return;
}

use namespace::autoclean;

1;

__END__

=pod

=encoding utf-8

=head1 Name

App::MCP::Context - Master Control Program - Dependency and time based job scheduler

=head1 Synopsis

   use App::MCP::Context;
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

=item L<Moo>

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
