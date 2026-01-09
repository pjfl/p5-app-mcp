package App::MCP::Role::Authorisation;

use App::MCP::Constants   qw( EXCEPTION_CLASS FALSE NUL TRUE );
use App::MCP::Util        qw( redirect );
use Unexpected::Functions qw( throw NoUserRole );
use Moo::Role;

sub is_authorised {
   my ($self, $context, $action) = @_;

   my $role = _get_action_auth($context, $action) // 'edit';

   return TRUE if $role eq 'none';

   my $session = $context->session;

   return $self->_redirect2login($context) unless $session->authenticated;

   return TRUE if $role eq 'view';

   my $user_role = $session->role or throw NoUserRole, [$session->username];

   return TRUE if $user_role eq 'admin';

   return TRUE if $user_role eq 'manager' and $role eq 'edit';

   return TRUE if $user_role eq $role;

   $context->stash(redirect $context->uri_for_action('misc/unauthorised'), []);

   return FALSE;
}

sub method_args {
   my ($self, $context, $action, $uri_args) = @_;

   my $captures = _get_captures($context, $action);

   return $uri_args unless $captures;

   my $method_args = [];

   for (1 .. $captures) {
      my $arg = shift @{$uri_args};

      last unless defined $arg;

      push @{$method_args}, $arg;
   }

   return $method_args;
}

# Private methods
sub _redirect2login {
   my ($self, $context) = @_;

   my $login   = $context->uri_for_action('misc/login');
   my $wanted  = $context->request->uri;
   my $session = $context->session;
   my $method  = $context->endpoint;
   my $action  = $self->can($method // NUL);

   # Redirect to wanted on successful login. Only set wanted to "legit" uris
   $session->wanted("${wanted}") if !$session->wanted
      && !$wanted->query_form('navigation')
      && ($method ne 'login')
      && ($method ne 'logout')
      && _get_nav_label($context, $action);

   $context->stash(redirect $login, ['Authentication required']);

   return FALSE;
}

# Private functions
sub _get_action_auth {
   my ($context, $action) = @_;

   return unless $action;

   my $attr = eval { $context->get_attributes($action) };

   return $attr->{Auth}->[-1] if $attr && defined $attr->{Auth};

   return;
}

sub _get_captures {
   my ($context, $action) = @_;

   return unless $action;

   my $attr = eval { $context->get_attributes($action) };

   return $attr->{Capture}->[-1] if $attr && defined $attr->{Capture};

   return;
}

sub _get_nav_label {
   my ($context, $action) = @_;

   return unless $action;

   my $attr = eval { $context->get_attributes($action) };

   return $attr->{Nav}->[-1] if $attr && defined $attr->{Nav};

   return;
}

use namespace::autoclean;

1;
