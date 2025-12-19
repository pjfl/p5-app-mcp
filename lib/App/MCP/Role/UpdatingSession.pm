package App::MCP::Role::UpdatingSession;

use App::MCP::Constants qw( FALSE TRUE );
use Scalar::Util        qw( blessed );
use Moo::Role;

sub update_session {
   my ($self, $session, $profile) = @_;

   for my $key (grep { $_ ne 'authenticated' } keys %{$profile}) {
      my $value = $profile->{$key};

      $value = "${value}"    if blessed $value;
      $session->$key($value) if defined $value && $session->can($key);
   }

   return;
}

use namespace::autoclean;

1;
