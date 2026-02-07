package App::MCP::Model::Misc;

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

has '+moniker' => default => 'misc';

has '+redis_client_name' => default => 'job_stash';

sub base : Auth('none') {
   my ($self, $context) = @_;

   $context->stash('nav')->finalise;
   return;
}

sub user : Auth('none') {
   my ($self, $context, $id_or_name) = @_;

   $self->_stash_user($context, $id_or_name);
   $context->stash('nav')->finalise;
   return;
}

sub changes : Auth('none') Nav('Changes') {
   my ($self, $context) = @_;

   $context->stash(form => $self->new_form('Changes', { context => $context }));
   return;
}

sub create_user : Auth('none') {
   my ($self, $context, $token) = @_;

   my $stash = $self->redis_client->get($token);

   return $self->error($context, UnknownToken, [$token]) unless $stash;

   $self->redis_client->remove($token);

   my $user = $context->model('User')->create({
      email            => $stash->{email},
      name             => $stash->{username},
      password         => $stash->{password},
      password_expired => TRUE,
      role_id          => $stash->{role_id},
   });
   my $changep = $context->uri_for_action('misc/password', [$user->id]);
   my $message = 'User [_1] created';

   $context->stash(redirect $changep, [$message, "${user}"]);
   return;
}

sub default : Auth('none') {
   my ($self, $context) = @_;

   my $default = $context->uri_for_action($self->config->default_action);

   $context->stash(redirect $default, ['Redirecting to [_1]', $default]);
   return;
}

sub footer : Auth('none') {
   my ($self, $context, $moniker, $method) = @_;

   $context->stash(page => { layout => 'site/footer' });

   my $action    = "${moniker}/footer";
   my $session   = $context->session;
   my $templates = $context->views->{html}->templates;
   my $footer    = $templates->catdir($session->skin)->catfile("${action}.tt");

   $context->stash(page => { layout => $action }) if $footer->exists;

   $action = "${moniker}/${method}_footer";
   $footer = $templates->catdir($session->skin)->catfile("${action}.tt");

   $context->stash(page => { layout => $action }) if $footer->exists;

   return;
}

sub login : Auth('none') Nav('Sign In') {
   my ($self, $context) = @_;

   my $options = { context => $context, log => $self->log };
   my $form    = $self->new_form('Login', $options);

   if ($form->process(posted => $context->posted)) {
      my $default  = $context->uri_for_action($self->config->default_action);
      my $name     = $context->session->username;
      my $wanted   = $context->session->wanted;
      my $location = new_uri $context->request->scheme, $wanted if $wanted;
      my $address  = $context->request->remote_address;
      my $message  = 'User [_1] logged in';

      $self->log->info("Address ${address}", $context);
      $context->stash(redirect $location || $default, [$message, $name]);
      $context->session->wanted(NUL);
   }

   $context->stash(form => $form);
   return;
}

sub login_dispatch : Auth('none') {
   my ($self, $context) = @_;

   my $user = $context->body_parameters->{user_name};

   if ($context->button_pressed eq 'password_reset') {
      $self->password_reset($context) if $self->_stash_user($context, $user);
   }
   elsif ($context->button_pressed eq 'totp_reset') {
      my $reset = $context->uri_for_action('misc/totp_reset', [$user]);

      $context->stash(redirect $reset, ['Redirecting to OTP reset']);
   }
   elsif ($user) { $context->stash(forward => 'misc/login') }
   else { $context->stash(forward => 'misc/not_found') }

   return;
}

sub logout : Auth('view') Nav('Logout') {
   my ($self, $context) = @_;

   return unless $self->verify_form_post($context);

   my $login   = $context->uri_for_action('misc/login');
   my $message = 'User [_1] logged out';

   $context->logout;
   $context->stash(redirect $login, [$message, $context->session->username]);
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

   my $user    = $context->stash('user');
   my $options = { context => $context, item => $user, log => $self->log };
   my $form    = $self->new_form('ChangePassword', $options);

   if ($form->process(posted => $context->posted)) {
      my $default = $context->uri_for_action($self->config->default_action);
      my $message = 'User [_1] changed password';

      $context->stash(redirect $default, [$message, "${user}"]);
   }

   $context->stash(form => $form);
   return;
}

sub password_reset : Auth('none') {
   my ($self, $context, $token) = @_;

   $context->action('misc/password_reset');

   return unless $self->verify_form_post($context);

   my $user = $context->stash('user');

   unless ($user->can_email) {
      my $login   = $context->uri_for_action('misc/login');
      my $message = 'User [_1] no email address';

      $context->stash(redirect $login, [$message, "${user}"]);
      return;
   }

   my $job     = $self->_create_reset_email($context, $user);
   my $changep = $context->uri_for_action('misc/password', [$user->id]);
   my $message = 'User [_1] password reset request [_2] created';

   $context->stash(redirect $changep, [$message, "${user}", "${job}"]);
   return;
}

sub password_update : Auth('none') {
   my ($self, $context, $token) = @_;

   my $stash = $self->redis_client->get($token)
      or return $self->error($context, UnknownToken, [$token]);
   my $user  = $context->stash('user');

   $user->update({ password => $stash->{password}, password_expired => TRUE });

   my $changep = $context->uri_for_action('misc/password', [$user->id]);
   my $message = 'User [_1] password reset and expired';

   $context->stash(redirect $changep, [$message, "${user}"]);
   $self->redis_client->remove($token);
   return;
}

sub register : Auth('none') Nav('Sign Up') {
   my ($self, $context) = @_;

   return $self->error($context, UnauthorisedAccess)
      unless $self->config->registration;

   my $options = { context => $context, log => $self->log };
   my $form    = $self->new_form('Register', $options);

   if ($form->process(posted => $context->posted)) {
      my $job     = $context->stash->{job};
      my $login   = $context->uri_for_action('misc/login');
      my $message = 'Registration request [_1] created';

      $context->stash(redirect $login, [$message, "${job}"]);
      return;
   }

   $context->stash(form => $form);
   return;
}

sub totp : Auth('none') {
   my ($self, $context, $token) = @_;

   return $self->error($context, UnknownToken, [$token])
      unless $self->redis_client->get($token);

   $self->redis_client->remove($token);

   my $options = { context => $context, user => $context->stash('user') };

   $context->stash(form => $self->new_form('TOTP::Secret', $options));
   return;
}

sub totp_reset : Auth('none') {
   my ($self, $context) = @_;

   my $user    = $context->stash('user');
   my $options = { context => $context, log => $self->log, user => $user };
   my $form    = $self->new_form('TOTP::Reset', $options);

   if ($form->process(posted => $context->posted)) {
      my $job     = $context->stash->{job};
      my $login   = $context->uri_for_action('misc/login');
      my $message = 'User [_1] TOTP reset request [_2] created';

      $context->stash(redirect $login, [$message, "${user}", "${job}"]);
   }

   $context->stash(form => $form);
   return;
}

sub unauthorised : Auth('none') {
   my ($self, $context) = @_;

   $self->error($context, UnauthorisedAccess);
   return;
}

# Private methods
sub _create_reset_email {
   my ($self, $context, $user) = @_;

   my $token   = create_token;
   my $actionp = 'misc/password_reset';
   my $link    = $context->uri_for_action($actionp, [$user->id, $token]);
   my $passwd  = substr create_token, 0, 12;
   my $params  = {
      application => $self->config->name,
      link        => "${link}",
      password    => $passwd,
      recipients  => [$user->id],
      subject     => 'Password Reset',
      template    => 'password_reset.md',
   };
   my $job;

   try   { $job = $self->send_message($context, $token, $params) }
   catch { $self->error($context, $_) };

   return $job;
}

sub _stash_user {
   my ($self, $context, $id_or_name) = @_;

   my $realm = $context->session->realm;
   my $user  = $context->find_user({ username => $id_or_name }, $realm);

   return $self->error($context, UnknownUser, [$id_or_name]) unless $user;

   $context->stash(user => $user);
   return TRUE;
}

1;

__END__

=pod

=encoding utf8

=head1 Name

App::MCP::Model::Misc - One-line description of the modules purpose

=head1 Synopsis

   use App::MCP::Model::Misc;
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
