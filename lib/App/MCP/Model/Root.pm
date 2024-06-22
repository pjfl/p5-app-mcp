package App::MCP::Model::Root;

use App::MCP::Constants   qw( EXCEPTION_CLASS FALSE NUL TRUE );
use HTTP::Status          qw( HTTP_OK );
use App::MCP::Util        qw( create_token new_uri redirect );
use JSON::MaybeXS         qw( encode_json );
use Type::Utils           qw( class_type );
use Unexpected::Functions qw( PageNotFound UnknownToken UnknownUser );
use App::MCP::Redis;
use Try::Tiny;
use Moo;
use App::MCP::Attributes; # Will do cleaning

extends 'App::MCP::Model';
with    'Web::Components::Role';

has '+moniker' => default => 'page';

has 'redis' =>
   is      => 'lazy',
   isa     => class_type('App::MCP::Redis'),
   default => sub {
      my $self   = shift;
      my $config = $self->config;
      my $name   = $config->prefix . '_job_stash';

      return App::MCP::Redis->new(
         client_name => $name, config => $config->redis
      );
   };

sub base : Auth('none') {
   my ($self, $context, $id_or_name) = @_;

   $self->_stash_user($context, $id_or_name);
   $context->stash('nav')->finalise;
   return;
}

sub access_denied : Auth('none') {}

sub changes : Auth('none') Nav('Changes') {
   my ($self, $context) = @_;

   $context->stash(form => $self->new_form('Changes', { context => $context }));
   return;
}

sub configuration : Auth('admin') Nav('Configuration') {
   my ($self, $context) = @_;

   my $options = { context => $context };

   $context->stash(form => $self->new_form('Configuration', $options));
   return;
}

sub default : Auth('none') {
   my ($self, $context) = @_;

   my $default = $context->uri_for_action($self->config->redirect);

   $context->stash(redirect $default, []);
   return;
}

sub login : Auth('none') Nav('Login') {
   my ($self, $context) = @_;

   my $params = $context->get_body_parameters;

   if ($params->{_submit} && $params->{_submit} eq 'password_reset') {
      $self->_stash_user($context, $params->{user_name});
      $self->password_reset($context);
      return;
   }

   if ($params->{_submit} && $params->{_submit} eq 'totp_reset') {
      $context->stash(redirect $context->uri_for_action(
         'page/totp_reset', [$params->{user_name}, 'reset']
      ), []);
      return;
   }

   my $options = { context => $context, log => $self->log };
   my $form    = $self->new_form('Login', $options);

   if ($form->process(posted => $context->posted)) {
      my $default  = $context->uri_for_action($self->config->redirect);
      my $username = $context->session->username;
      my $wanted   = $context->session->wanted;
      my $location = new_uri $context->request->scheme, $wanted if $wanted;
      my $message  = 'User [_1] logged in';

      $context->stash(redirect $location || $default, [$message, $username]);
      $context->session->wanted(NUL);
   }

   $context->stash(form => $form);
   return;
}

sub logout : Auth('view') Nav('Logout') {
   my ($self, $context) = @_;

   return unless $context->verify_form_post;

   my $default = $context->uri_for_action('page/login');
   my $message = 'User [_1] logged out';
   my $session = $context->session;

   $session->authenticated(FALSE);
   $session->role(NUL);
   $session->wanted(NUL);
   $context->stash(redirect $default, [$message, $session->username]);
   return;
}

sub not_found : Auth('none') {
   my ($self, $context) = @_;

   return $self->error($context, PageNotFound, [$context->request->path]);
}

# TODO: Move to api
sub object_property : Auth('none') {
   my ($self, $context) = @_;

   my $req   = $context->request;
   my $class = $req->query_params->('class');
   my $prop  = $req->query_params->('property');
   my $value = $req->query_params->('value', { raw => TRUE });
   my $resp  = { found => \0 };

   if ($value) {
      try { # Defensively written
         my $r = $context->model($class)->find_by_key($value);

         $resp->{found} = \1 if $r && $r->execute($prop);
      }
      catch { $self->log->error($_, $context) };
   }

   $context->stash(json => $resp, code => HTTP_OK, view => 'json');
   return;
}

sub password : Auth('none') Nav('Change Password') {
   my ($self, $context) = @_;

   my $user    = $context->stash('user') or return;
   my $options = { context => $context, item => $user, log => $self->log };
   my $form    = $self->new_form('ChangePassword', $options);

   if ($form->process( posted => $context->posted )) {
      my $default = $context->uri_for_action($self->config->redirect);
      my $message = 'User [_1] changed password';

      $context->stash(redirect $default, [$message, $form->item->name]);
   }

   $context->stash(form => $form);
   return;
}

sub password_reset : Auth('none') {
   my ($self, $context, $userid, $token) = @_;

   my $user    = $context->stash('user') or return;
   my $changep = $context->uri_for_action('page/password', [$user->id]);

   if (!$context->posted && $token && $token ne 'reset') {
      my $stash = $self->redis->get($token)
         or return $self->error($context, UnknownToken, [$token]);

      $user->update({password => $stash->{password}, password_expired => TRUE});

      my $message = 'User [_1] password reset';

      $context->stash(redirect $changep, [$message, "${user}"]);
      $self->redis->remove($token);
      return;
   }

   return unless $context->posted;
   return unless $context->verify_form_post;

   unless ($user->can_email) {
      my $login   = $context->uri_for_action('page/login');
      my $message = 'User [_1] no email address';

      $context->stash(redirect $login, [$message, "${user}"]);
      return;
   }

   $token = create_token;

   my $actionp = 'page/password_reset';
   my $link    = $context->uri_for_action($actionp, [$user->id, $token]);
   my $passwd  = substr create_token, 0, 12;
   my $options = {
      application => $self->config->name,
      link        => "${link}",
      password    => $passwd,
      recipients  => [$user->id],
      subject     => 'Password Reset',
      template    => 'password_reset.md',
   };
   my $job     = $self->_send_email($context, $token, $options);
   my $message = 'User [_1] password reset request [_2] dispatched';

   $context->stash(redirect $changep, [$message, "${user}", $job->label]);
   return;
}

# Private methods
sub _send_email {
   my ($self, $context, $token, $args) = @_;

   $self->redis->set($token, encode_json($args));

   my $program = $self->config->bin->catfile('mcat-cli');
   my $command = "${program} -o token=${token} send_message email";
   my $options = { command => $command, name => 'send_message' };

   return $context->model('SystemJob')->create($options);
}

sub _stash_user {
   my ($self, $context, $id_or_name) = @_;

   return unless $id_or_name;

   my $realm = $context->session->realm;
   my $user  = $context->find_user({ username => $id_or_name }, $realm)
      or return $self->error($context, UnknownUser, [$id_or_name]);

   $context->stash(user => $user);
   return;
}

1;

__END__

=pod

=encoding utf8

=head1 Name

App::MCP::Model::Root - One-line description of the modules purpose

=head1 Synopsis

   use App::MCP::Model::Root;
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
