package App::MCP::Form::Login;

use HTML::Forms::Constants qw( FALSE META NUL SPC TRUE );
use Class::Usul::Cmd::Util qw( includes );
use HTML::Forms::Util      qw( make_handler );
use App::MCP::Util         qw( redirect );
use Scalar::Util           qw( blessed );
use Unexpected::Functions  qw( catch_class );
use Try::Tiny;
use Moo;
use HTML::Forms::Moo;

extends 'HTML::Forms';
with    'HTML::Forms::Role::Defaults';

has '+info_message' => default => 'Stop! You have your papers?';
has '+item_class'   => default => 'User';
has '+name'         => default => 'Login';
has '+title'        => default => 'Sign In';

has_field 'name' =>
   autocomplete => TRUE,
   element_attr => { placeholder => SPC },
   html_name    => 'user_name',
   input_param  => 'user_name',
   label        => 'User Name',
   label_top    => TRUE,
   required     => TRUE,
   title        => 'Enter your user name or email address';

has_field 'password' =>
   type         => 'Password',
   autocomplete => TRUE,
   element_attr => { placeholder => SPC },
   label_top    => TRUE,
   title        => 'Enter your password';

has_field 'auth_code' =>
   type          => 'Digits',
   label         => 'OTP Code',
   label_top     => TRUE,
   size          => 6,
   title         => 'Enter the Authenticator code',
   wrapper_class => ['input-integer'];

has_field 'login' =>
   type          => 'Button',
   disabled      => TRUE,
   element_attr  => { 'data-field-depends' => [qw(user_name password)] },
   html_name     => 'submit',
   label         => 'Submit',
   value         => 'login';

has_field 'register' =>
   type          => 'Link',
   element_attr  => { 'data-field-depends' => ['!user_name'] },
   element_class => ['form-button'],
   label         => 'Sign Up',
   title         => 'Register for a login account',
   wrapper_class => ['input-button'];

has_field 'totp_reset' =>
   type          => 'Button',
   disabled      => TRUE,
   element_attr  => { 'data-field-depends' => ['user_name'] },
   html_name     => 'submit',
   label         => 'OTP Reset',
   title         => 'Request an OTP reset',
   value         => 'totp_reset';

has_field 'password_reset' =>
   type          => 'Button',
   allow_default => TRUE,
   disabled      => TRUE,
   element_attr  => { 'data-field-depends' => ['user_name'] },
   html_name     => 'submit',
   label         => 'Password Reset',
   title         => 'Send password reset email',
   value         => 'password_reset';

has_field 'oauth_login' =>
   type          => 'Button',
   html_name     => 'submit',
   label         => 'OAuth Login',
   title         => 'Login using an OAuth service provider',
   value         => 'oauth_login';

after 'after_build_fields' => sub {
   my $self    = shift;
   my $context = $self->context;
   my $config  = $context->config;
   my $session = $context->session;

   $self->set_form_element_attr('novalidate', 'novalidate');

   $self->add_form_element_class('radar')
      if includes 'radar', $session->features;

   unless ($session->enable_2fa) {
      $self->field('auth_code')->add_wrapper_class('hide');
      $self->field('totp_reset')->add_wrapper_class('hide');
   }

   if (includes 'droplets', $session->features) {
      $self->add_form_element_class('droplets');

      my $buttons = [qw(register password_reset totp_reset oauth_login)];

      $self->_add_field_wrapper_class('droplet', $buttons);

      my $uri = $context->uri_for_action('misc/register');

      $self->field('register')->href($uri->as_string);
   }
   else {
      my $buttons = [qw(login register password_reset totp_reset oauth_login)];

      $self->_add_field_wrapper_class('expand', $buttons);
      $self->field('register')->inactive(TRUE);
   }

   $self->field('register')->inactive(TRUE) unless $config->registration;

   $self->field('oauth_login')->add_wrapper_class('hide');
   $self->_add_field_handlers;
   return;
};

around 'validate_form' => sub {
   my ($orig, $self) = @_;

   my @modified_fields;

   for my $name (qw(auth_code password)) {
      my $field_obj = $self->field($name);

      $field_obj->required(FALSE);
      push @modified_fields, $field_obj;
   }

   $orig->($self);

   $_->required(TRUE) for (@modified_fields);

   return;
};

sub validate {
   my $self = shift;

   return unless $self->validated;

   my ($username, $realm) = $self->_get_realm;

   my $context = $self->context;
   my $options = { prefetch => ['profile', 'role'] };
   my $args    = { username => $username, options => $options };
   my $user    = $context->find_user($args, $realm);
   my $name    = $self->field('name');

   return $name->add_error('User [_1] unknown', $username) unless $user;

   my $passwd  = $self->field('password');
   my $code    = $self->field('auth_code');

   $args = {
      address  => $context->request->remote_address,
      code     => $code->value,
      password => $passwd->value,
      user     => $user,
   };

   try {
      $context->logout;
      $context->authenticate($args, $realm);
      $context->set_authenticated($args, $realm);
   }
   catch_class $self->_exception_handlers($user, $passwd, $code);

   return;
}

# Private methods
sub _add_field_handlers {
   my $self      = shift;
   my $form_util = $self->context->config->wcom_resources->{form_util};

   my $change_js = "${form_util}.fieldChange";
   my $showif_js = "${form_util}.showIfRequired";
   my $unreq_js  = "${form_util}.unrequire";

   my $change_flds = [qw(login register password_reset totp_reset)];
   my $showif_flds = ['auth_code','totp_reset'];
   my $unreq_flds  = ['auth_code', 'password'];

   my $options_2fa = $self->_check_prop('user_name', 'is_2fa_enabled');
   my $options_oa  = $self->_check_prop('user_name', 'is_oauth_enabled');
   my $options_pwd = $self->_check_prop('user_name', '!is_password_enabled');
   my $handler     = make_handler($showif_js, $options_2fa, $showif_flds)
            . '; ' . make_handler($showif_js, $options_oa,  ['oauth_login'])
            . '; ' . make_handler($showif_js, $options_pwd, ['password']);

   $self->field('name')->add_handler('blur', $handler);
   $handler = make_handler($change_js, { id => 'user_name' }, $change_flds);
   $self->field('name')->add_handler('input', $handler);

   $handler = make_handler($change_js, { id => 'password' }, $change_flds);
   $self->field('password')->add_handler('input', $handler);

   $handler = make_handler($change_js, { id => 'auth_code' }, $change_flds);
   $self->field('auth_code')->add_handler('blur', $handler);

   $handler = make_handler($unreq_js, { allow_default => TRUE }, $unreq_flds);
   $self->field('password_reset')->add_handler('click', $handler);
   $self->field('totp_reset')->add_handler('click', $handler);
   $self->field('oauth_login')->add_handler('click', $handler);
   return;
}

sub _add_field_wrapper_class {
   my ($self, $class, $list) = @_;

   for my $name (@{$list}) {
      $self->field($name)->add_wrapper_class($class);
   }

   return;
}

sub _check_prop {
   my ($self, $id, $property) = @_;

   my $context = $self->context;
   my $config  = $context->config;
   my $params  = { class => 'User', property => $property };
   my $uri     = $context->uri_for_action('api/fetch', ['property'], $params);

   return { id => $id, url => "${uri}" };
}

sub _exception_handlers {
   my ($self, $user, $passwd, $code) = @_;

   my $context = $self->context;

   return [
      'IncorrectAuthCode' => sub { $code->add_error($_->original) },
      'IncorrectPassword' => sub { $passwd->add_error($_->original) },
      'InvalidIPAddress'  => sub {
         $self->add_form_error($_->original);
         $self->log->alert($_->original, $context) if $self->has_log;
      },
      'PasswordExpired'   => sub {
         my $changep = $context->uri_for_action('misc/password', [$user->id]);

         $passwd->add_error($_->original);
         $context->stash(redirect $changep, [$_->original]);
         $context->stash('redirect')->{level} = 'alert' if $self->has_log;
      },
      'Authentication' => sub { $self->add_form_error($_->original) },
      'RedirectToLocation' => sub {
         my $params = { http_headers => { 'X-Force-Reload' => 'true' }};

         $self->add_form_error($_->original);
         $context->stash(redirect $_->args->[0], [$_->original], $params);
      },
      'Unspecified'    => sub {
         if ($_->args->[0] eq 'Password') { $passwd->add_error($_->original) }
         else { $code->add_error($_->original) }
      },
      '*' => sub {
         my $error = blessed $_ && $_->can('original') ? $_->original : "${_}";

         $self->add_form_error($error);
         $self->log->alert($error, $context) if $self->has_log;
      }
   ];
}

sub _get_realm {
   my $self = shift;

   my ($username, $realm) = reverse split m{ : }mx, $self->field('name')->value;

   $realm = 'OAuth' if $self->context->button_pressed eq 'oauth_login';
   $realm = 'OAuth' if $self->field('password')->value eq 'oauth';
   $realm = 'OAuth' if $realm && $realm eq 'oauth';

   return ($username, $realm);
}

use namespace::autoclean -except => META;

1;

__END__

=pod

=encoding utf-8

=head1 Name

App::MCP::Form::Login - Master Control Program - Dependency and time based job scheduler

=head1 Synopsis

   use App::MCP::Form::Login;
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

=item L<HTML::Forms>

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
