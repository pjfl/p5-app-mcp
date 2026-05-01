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

=pod

=encoding utf-8

=head1 Name

App::MCP::Context - Per request context object

=head1 Synopsis

   use App::MCP::Context;

=head1 Description

Per request context object

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=item C<config>

A required reference to the L<configuration|App::MCP::Config> object

=cut

has 'config' => is => 'ro', isa => ConfigProvider, required => TRUE;

=item C<icons_uri>

URI for the C<icons.svg> symbols file

=cut

has 'icons_uri' =>
   is      => 'lazy',
   isa     => class_type('URI'),
   default => sub {
      my $self = shift;

      return $self->request->uri_for($self->config->icons);
   };

=item C<response>

An instance of the L<response|App::MCP::Response> object

=cut

has 'response' =>
   is      => 'lazy',
   isa     => class_type('App::MCP::Response'),
   default => sub { App::MCP::Response->new };

=item C<time_zone>

The user's time zone. Taken from the L<session|Web::ComposableRequest::Session>
object

=cut

has 'time_zone' =>
   is      => 'lazy',
   isa     => Str,
   default => sub { shift->session->timezone };

=item C<token_lifetime>

How long in seconds should the CSRF last for

=cut

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

=back

=head1 Subroutines/Methods

Defines the following methods;

=over 3

=item C<feature>

   $name = $self->feature($name);

Returns the feature C<name> iff the user has the feature turned on

=cut

sub feature {
   my ($self, $feature) = @_;

   return includes $feature, $self->session->features;
}

=item C<get_attributes>

   $attribute_hash = $self->get_attributes($action);

Returns the subroutine attributes associated with the given action. The
C<action> can be either an action path (moniker/method) or a code reference

=cut

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

=item C<is_authorised>

   $bool = $self->is_authorised($action);

Returns true of false depending on whether the user has access to the action.
The C<action> should be an action path (moniker/method)

=cut

sub is_authorised {
   my ($self, $actionp) = @_;

   return FALSE unless $actionp;

   my ($moniker) = split m{ / }mx, $actionp;

   return FALSE unless $moniker;

   my $model = $self->models->{$moniker};

   return FALSE unless $model;

   my $authorised = $model->is_authorised($self, $actionp);

   $self->clear_redirect;
   return $authorised;
}

=item C<method_chain>

   $chain = $self->method_chain($action);

Returns the moniker/method_dispatch_chain for the given action

=cut

sub method_chain {
   my ($self, $action) = @_;

   return $self->_action_path2methods($action);
}

=item C<model>

   $resultset = $self->model($name);

Returns the resultset form the given name

=cut

sub model {
   my ($self, $rs_name) = @_;

   return $rs_name ? $self->schema->resultset($rs_name) : undef;
}

=item C<res>

   $response = $self->res;

Returns the response object

=cut

sub res { shift->response }

=item C<uri_for_action>

   $uri = $self->uri_for_action($action, \@args?, \%params?);

Returns the URI for the given action. Optional array reference of positional
arguments should be provided if required. Options hash reference of query
string keys and values may be provided

=cut

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

=item C<verification_token>

   $token = $self->verification_token;

Returns a freshly minted CSRF token

=cut

sub verification_token {
   my $self = shift;

   return get_token $self->token_lifetime, $self->session->serialise;
}

=item C<verify_form_post>

   $reason = $self->verify_form_post;

Returns the reason why the form post CSRF token was rejected. Returns undefined
if the token is good

=cut

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

=back

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<attributes>

=item L<Web::Components::Context>

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
