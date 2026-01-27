package App::MCP::Form::TOTP::Secret;

use HTML::Forms::Constants qw( FALSE META TRUE );
use Moo;
use HTML::Forms::Moo;

extends 'HTML::Forms';
with    'HTML::Forms::Role::Defaults';

has '+default_field_traits' => default => sub { [] };
has '+info_message'         => default
                            => 'Capture the QR with your mobile device';
has '+no_update'            => default => TRUE;
has '+title'                => default => 'TOTP Account Information';

has 'user' => is => 'ro', required => TRUE;

has_field 'name' => type => 'Display', label => 'User Name';

has_field 'totp_qr_code' => type => 'Image', label => 'QR Code';

has_field 'totp_auth' => type => 'Display', label => 'Authentication URI';

around 'after_build_fields' => sub {
   my ($orig, $self) = @_;

   $orig->($self);

   my $auth = $self->user->authenticator;

   $self->field('name')->default($self->user->user_name);
   $self->field('totp_qr_code')->src($auth->qr_code);
   $self->field('totp_auth')->default($auth->otpauth);
   return;
};

use namespace::autoclean -except => META;

1;
