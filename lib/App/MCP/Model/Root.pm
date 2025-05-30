package App::MCP::Model::Root;

use App::MCP::Constants    qw( EXCEPTION_CLASS FALSE NUL TRUE );
use HTTP::Status           qw( HTTP_OK );
use App::MCP::Util         qw( create_token new_uri redirect );
use Unexpected::Functions  qw( PageNotFound UnauthorisedAccess
                               UnknownToken UnknownUser );
use Try::Tiny;
use Moo;
use App::MCP::Attributes; # Will do cleaning

extends 'App::MCP::Model';
with    'Web::Components::Role';
with    'App::MCP::Role::Redis';
with    'App::MCP::Role::SendMessage';

has '+moniker' => default => 'page';

has '+redis_client_name' => default => 'job_stash';

sub base : Auth('none') {
   my ($self, $context, $id_or_name) = @_;

   $self->_stash_user($context, $id_or_name) if $id_or_name;
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

   my $params    = $context->get_body_parameters;
   my $username  = $params->{user_name};
   my $submitter = $params->{_submit} // NUL;

   if ($submitter eq 'password_reset') {
      $self->_stash_user($context, $username) if $username;
      $self->password_reset($context);
      return;
   }

   if ($submitter eq 'totp_reset') {
      my $args  = [$username, 'reset'];
      my $reset = $context->uri_for_action('page/totp_reset', $args);

      $context->stash(redirect $reset, []);
      return;
   }

   my $options = { context => $context, log => $self->log };
   my $form    = $self->new_form('Login', $options);

   if ($form->process(posted => $context->posted)) {
      my $message  = ['User [_1] logged in', $context->session->username];
      my $wanted   = $context->session->wanted;
      my $location = $wanted ? new_uri $context->request->scheme, $wanted
                   : $context->uri_for_action($self->config->redirect);

      $context->stash(redirect $location, $message);
      $context->session->wanted(NUL);
   }

   $context->stash(form => $form);
   return;
}

sub logout : Auth('view') Nav('Logout') {
   my ($self, $context) = @_;

   return unless $self->verify_form_post($context);

   my $login   = $context->uri_for_action('page/login');
   my $message = ['User [_1] logged out', $context->session->username];

   $context->logout;
   $context->stash(redirect $login, $message);
   return;
}

sub not_found : Auth('none') {
   my ($self, $context) = @_;

   my $request = $context->request;

   if (($request->query_parameters->{navigation} // NUL) eq 'true') {
      $context->stash(json => {}, view => 'json');
      return;
   }

   $self->error($context, PageNotFound, [$request->path]);
   return;
}

sub password : Auth('none') Nav('Change Password') {
   my ($self, $context) = @_;

   my $user    = $context->stash('user') or return;
   my $options = { context => $context, item => $user, log => $self->log };
   my $form    = $self->new_form('ChangePassword', $options);

   if ($form->process( posted => $context->posted )) {
      my $default = $context->uri_for_action($self->config->redirect);
      my $message = ['User [_1] changed password', $form->item->name];

      $context->stash(redirect $default, $message);
   }

   $context->stash(form => $form);
   return;
}

sub password_reset : Auth('none') {
   my ($self, $context, $userid, $token) = @_;

   my $user    = $context->stash('user') or return;
   my $changep = $context->uri_for_action('page/password', [$user->id]);

   if (!$context->posted && $token && $token ne 'reset') {
      my $stash = $self->redis_client->get($token)
         or return $self->error($context, UnknownToken, [$token]);

      $user->update({password => $stash->{password}, password_expired => TRUE});

      my $message = ['User [_1] password reset', "${user}"];

      $context->stash(redirect $changep, $message);
      $self->redis_client->remove($token);
      return;
   }

   return unless $context->posted;
   return unless $self->verify_form_post($context);

   my $job     = $self->_create_reset_email($context) or return;
   my $text    = 'User [_1] password reset request [_2] created';
   my $message = [$text, "${user}", $job->job_name];

   $context->stash(redirect $changep, $message);
   return;
}

sub register : Auth('none') Nav('Register') {
   my ($self, $context, $token) = @_;

   return $self->error($context, UnauthorisedAccess)
      unless $self->config->registration;

   return $self->_create_user($context, $token)
      if !$context->posted && $token;

   my $options = { context => $context, log => $self->log };
   my $form    = $self->new_form('Register', $options);

   if ($form->process(posted => $context->posted)) {
      my $job     = $context->stash->{job};
      my $login   = $context->uri_for_action('page/login');
      my $message = ['Registration request [_1] dispatched', $job->job_name];

      $context->stash(redirect $login, $message);
      return;
   }

   $context->stash(form => $form);
   return;
}

sub totp_reset : Auth('none') {
   my ($self, $context, $userid, $token) = @_;

   my $user    = $context->stash('user') or return;
   my $options = { context => $context, log => $self->log, user => $user };

   if (!$context->posted && $token && $token ne 'reset') {
      my $stash = $self->redis_client->get($token)
         or return $self->error($context, UnknownToken, [$token]);

      $context->stash(form => $self->new_form('TOTP::Secret', $options));
      $self->redis_client->remove($token);
      return;
   }

   my $form = $self->new_form('TOTP::Reset', $options);

   if ($form->process(posted => $context->posted)) {
      my $job     = $context->stash->{job};
      my $login   = $context->uri_for_action('page/login');
      my $message = 'User [_1] TOTP reset request [_2] dispatched';

      $context->stash(redirect $login, [$message, "${user}", $job->job_name]);
   }

   $context->stash(form => $form);
   return;
}

# Private methods
sub _create_reset_email {
   my ($self, $context) = @_;

   my $user = $context->stash('user');

   unless ($user->can_email) {
      my $login   = $context->uri_for_action('page/login');
      my $message = ['User [_1] no email address', "${user}"];

      $context->stash(redirect $login, $message);
      return;
   }

   my $token   = create_token;
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
   my $job;

   try   { $job = $self->send_message($context, $token, $options) }
   catch { $self->error($context, $_) };

   return $job;
}

sub _create_user {
   my ($self, $context, $token) = @_;

   my $stash = $self->redis_client->get($token)
      or return $self->error($context, UnknownToken, [$token]);
   my $args  = {
      email            => $stash->{email},
      name             => $stash->{username},
      password         => $stash->{password},
      password_expired => TRUE,
      role_id          => $stash->{role_id},
   };
   my $user    = $context->model('User')->create($args);
   my $changep = $context->uri_for_action('page/password', [$user->id]);
   my $message = ['User [_1] created', $user->name];

   $context->stash(redirect $changep, $message);
   $self->redis_client->remove($token);
   return;
}

sub _stash_user {
   my ($self, $context, $id_or_name) = @_;

   my $realm = $context->session->realm;
   my $user  = $context->find_user({ username => $id_or_name }, $realm);

   return $self->error($context, UnknownUser, [$id_or_name]) unless $user;

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
