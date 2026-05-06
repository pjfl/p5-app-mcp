package App::MCP::Exception;

use HTTP::Status          qw( HTTP_BAD_REQUEST HTTP_NOT_FOUND
                              HTTP_REQUEST_TIMEOUT HTTP_UNAUTHORIZED );
use Unexpected::Types     qw( Int Object Str );
use Type::Utils           qw( class_type );
use Unexpected::Functions qw( has_exception );
use DateTime;
use DateTime::Format::Strptime;
use App::MCP;
use Moo;

extends 'Class::Usul::Cmd::Exception',
   'HTML::Forms::Exception',
   'HTML::StateTable::Exception',
   'Web::ComposableRequest::Exception::Authen::HTTP';

=pod

=encoding utf8

=head1 Name

App::MCP::Exception - Exception definitions

=head1 Synopsis

   use App::MCP::Exception;

=head1 Description

Exception definitions

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=item C<clean_leader>

=cut

has 'clean_leader' =>
   is      => 'lazy',
   isa     => Str,
   default => sub {
      my $self   = shift;
      my $leader = $self->leader;

      $leader =~ s{ : [ ]* \z }{}mx;

      return $leader;
   };

=item C<created>

=cut

has 'created' =>
   is      => 'ro',
   isa     => class_type('DateTime'),
   default => sub {
      my $dt  = DateTime->now(locale => 'en_GB', time_zone => 'UTC');
      my $fmt = DateTime::Format::Strptime->new(pattern => '%F %R');

      $dt->set_formatter($fmt);

      return $dt;
   };

=item C<rv>

=cut

has 'rv' => is => 'ro', isa => Int, default => 0;

=item C<version>

=cut

has 'version' =>
   is      => 'ro',
   isa     => Object,
   default => sub { $App::MCP::VERSION };

my $class = __PACKAGE__;

has '+class' => default => $class;

=back

=head1 Subroutines/Methods

Defines the following exceptions;

=over 3

=item C<APIMethodFailed>

=cut

has_exception $class;

has_exception 'APIMethodFailed', parents => [$class],
   error   => 'API class [_1] method [_2] call failed: [_3]',
   rv      => HTTP_BAD_REQUEST;

=item C<NoMethod>

=cut

has_exception 'NoMethod' => parents => [$class],
   error   => 'Class [_1] has no method [_2]', rv => HTTP_NOT_FOUND;

=item C<NoUserRole>

=cut

has_exception 'NoUserRole' => parents => [$class],
   error   => 'User [_1] no role found on session', rv => HTTP_NOT_FOUND;

=item C<PageNotFound>

=cut

has_exception 'PageNotFound' => parents => [$class],
   error   => 'Page [_1] not found', rv => HTTP_NOT_FOUND;

=item C<RedirectToLocation>

=cut

has_exception 'RedirectToLocation' => parents => [$class],
   error   => 'Redirecting to [_2]';

=item C<Timedout>

=cut

has_exception 'Timedout' => parents => [$class],
   error   => 'Timedout after [_1] seconds waiting for [_2]';

=item C<UnauthorisedAPICall>

=cut

has_exception 'UnauthorisedAPICall' => parents => [$class],
   error   => 'Class [_1] method [_2] unauthorised call attempt',
   rv      => HTTP_UNAUTHORIZED;

=item C<UnauthorisedAccess>

=cut

has_exception 'UnauthorisedAccess' => parents => [$class],
   error   => 'Access to resource denied', rv => HTTP_UNAUTHORIZED;

=item C<UnknownAPIClass>

=cut

has_exception 'UnknownAPIClass' => parents => [$class],
   error   => 'API class [_1] not found: [_2]', rv => HTTP_NOT_FOUND;

=item C<UnknownAPIMethod>

=cut

has_exception 'UnknownAPIMethod' => parents => [$class],
   error   => 'Class [_1] has no [_2] method', rv => HTTP_NOT_FOUND;

=item C<UnknownJob>

=cut

has_exception 'UnknownJob' => parents => [$class],
   error   => 'Job [_1] not found', rv => HTTP_NOT_FOUND;

=item C<UnknownModel>

=cut

has_exception 'UnknownModel' => parents => [$class],
   error   => 'Model [_1] (moniker) not found', rv => HTTP_NOT_FOUND;

=item C<UnknownRealm>

=cut

has_exception 'UnknownRealm' => parents => [$class],
   error   => 'Realm [_1] not found', rv => HTTP_NOT_FOUND;

=item C<UnknownRole>

=cut

has_exception 'UnknownRole' => parents => [$class],
   error   => 'Role [_1] not found', rv => HTTP_NOT_FOUND;

=item C<UnknownToken>

=cut

has_exception 'UnknownToken' => parents => [$class],
   error   => 'Token [_1] not found', rv => HTTP_NOT_FOUND;

=item C<UnknownUser>

=cut

has_exception 'UnknownUser' => parents => [$class],
   error   => 'User [_1] not found', rv => HTTP_NOT_FOUND;

=item C<Authentication>

=cut

has_exception 'Authentication' => parents => [$class];

=item C<AccountInactive>

=cut

has_exception 'AccountInactive' => parents => ['Authentication'],
   error   => 'User [_1] authentication failed', rv => HTTP_UNAUTHORIZED;

=item C<AuthenticationRequired>

=cut

has_exception 'AuthenticationRequired' => parents => ['Authentication'],
   error   => 'Resource [_1] authentication required';

=item C<IncorrectAuthCode>

=cut

has_exception 'IncorrectAuthCode' => parents => ['Authentication'],
   error   => 'User [_1] authentication failed', rv => HTTP_UNAUTHORIZED;

=item C<IncorrectPassword>

=cut

has_exception 'IncorrectPassword' => parents => ['Authentication'],
   error   => 'User [_1] authentication failed', rv => HTTP_UNAUTHORIZED;

=item C<InvalidIPAddress>

=cut

has_exception 'InvalidIPAddress' => parents => ['Authentication'],
   error   => 'User [_1] invalid IP address';

=item C<PasswordDisabled>

=cut

has_exception 'PasswordDisabled' => parents => ['Authentication'],
   error   => 'User [_1] password disabled', rv => HTTP_UNAUTHORIZED;

=item C<PasswordExpired>

=cut

has_exception 'PasswordExpired' => parents => ['Authentication'],
   error   => 'User [_1] password expired', rv => HTTP_UNAUTHORIZED;

=item C<Workflow>

=cut

has_exception 'Workflow'  => parents => [$class];

=item C<Condition>

=cut

has_exception 'Condition' => parents => ['Workflow'],
   error   => 'Condition not true';

=item C<Crontab>

=cut

has_exception 'Crontab'   => parents => ['Workflow'],
   error   => 'Not at this time';

=item C<Illegal>

=cut

has_exception 'Illegal'   => parents => ['Workflow'],
   error   => 'Transition [_1] from state [_2] illegal';

=item C<Retry>

=cut

has_exception 'Retry'     => parents => ['Workflow'],
   error   => 'Rv [_1] greater than expected [_2]';

=item C<Unknown>

=cut

has_exception 'Unknown'   => parents => ['Workflow'];

use namespace::autoclean;

1;

__END__

=back

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Unexpected>

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
