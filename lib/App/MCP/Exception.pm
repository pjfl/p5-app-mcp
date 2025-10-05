package App::MCP::Exception;

use HTTP::Status          qw( HTTP_BAD_REQUEST HTTP_NOT_FOUND
                              HTTP_UNAUTHORIZED );
use Unexpected::Types     qw( Int Object );
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

has 'created' =>
   is      => 'ro',
   isa     => class_type('DateTime'),
   default => sub {
      my $dt  = DateTime->now(locale => 'en_GB', time_zone => 'UTC');
      my $fmt = DateTime::Format::Strptime->new(pattern => '%F %R');

      $dt->set_formatter($fmt);

      return $dt;
   };

has 'rv' => is => 'ro', isa => Int, default => 0;

has 'version' =>
   is      => 'ro',
   isa     => Object,
   default => sub { $App::MCP::VERSION };

my $class = __PACKAGE__;

has '+class' => default => $class;

has_exception $class;

has_exception 'APIMethodFailed', parents => [$class],
   error   => 'API class [_1] method [_2] call failed: [_3]',
   rv      => HTTP_BAD_REQUEST;

has_exception 'NoMethod' => parents => [$class],
   error   => 'Class [_1] has no method [_2]', rv => HTTP_NOT_FOUND;

has_exception 'NoUserRole' => parents => [$class],
   error   => 'User [_1] no role found on session', rv => HTTP_NOT_FOUND;

has_exception 'PageNotFound' => parents => [$class],
   error   => 'Page [_1] not found', rv => HTTP_NOT_FOUND;

has_exception 'UnauthorisedAPICall' => parents => [$class],
   error   => 'Class [_1] method [_2] unauthorised call attempt',
   rv      => HTTP_UNAUTHORIZED;

has_exception 'UnauthorisedAccess' => parents => [$class],
   error   => 'Access to resource denied', rv => HTTP_UNAUTHORIZED;

has_exception 'UnknownAPIClass' => parents => [$class],
   error   => 'API class [_1] not found: [_2]', rv => HTTP_NOT_FOUND;

has_exception 'UnknownAPIMethod' => parents => [$class],
   error   => 'Class [_1] has no [_2] method', rv => HTTP_NOT_FOUND;

has_exception 'UnknownAttachment' => parents => [$class],
   error   => 'Attachment [_1] not found', rv => HTTP_NOT_FOUND;

has_exception 'UnknownBug' => parents => [$class],
   error   => 'Bug [_1] not found', rv => HTTP_NOT_FOUND;

has_exception 'UnknownJob' => parents => [$class],
   error   => 'Job [_1] not found', rv => HTTP_NOT_FOUND;

has_exception 'UnknownModel' => parents => [$class],
   error   => 'Model [_1] (moniker) not found', rv => HTTP_NOT_FOUND;

has_exception 'UnknownRole' => parents => [$class],
   error   => 'Role [_1] not found', rv => HTTP_NOT_FOUND;

has_exception 'UnknownToken' => parents => [$class],
   error   => 'Token [_1] not found', rv => HTTP_NOT_FOUND;

has_exception 'UnknownUser' => parents => [$class],
   error   => 'User [_1] not found', rv => HTTP_NOT_FOUND;

has_exception 'Authentication' => parents => [$class];

has_exception 'AccountInactive' => parents => ['Authentication'],
   error   => 'User [_1] authentication failed', rv => HTTP_UNAUTHORIZED;

has_exception 'AuthenticationRequired' => parents => ['Authentication'],
   error   => 'Resource [_1] authentication required';

has_exception 'IncorrectAuthCode' => parents => ['Authentication'],
   error   => 'User [_1] authentication failed', rv => HTTP_UNAUTHORIZED;

has_exception 'IncorrectPassword' => parents => ['Authentication'],
   error   => 'User [_1] authentication failed', rv => HTTP_UNAUTHORIZED;

has_exception 'PasswordDisabled' => parents => ['Authentication'],
   error   => 'User [_1] password disabled', rv => HTTP_UNAUTHORIZED;

has_exception 'PasswordExpired' => parents => ['Authentication'],
   error   => 'User [_1] password expired', rv => HTTP_UNAUTHORIZED;

has_exception 'Workflow'  => parents => [$class];

has_exception 'Condition' => parents => ['Workflow'],
   error   => 'Condition not true';

has_exception 'Crontab'   => parents => ['Workflow'],
   error   => 'Not at this time';

has_exception 'Illegal'   => parents => ['Workflow'],
   error   => 'Transition [_1] from state [_2] illegal';

has_exception 'Retry'     => parents => ['Workflow'],
   error   => 'Rv [_1] greater than expected [_2]';

has_exception 'Unknown'   => parents => ['Workflow'];

use namespace::autoclean;

1;

__END__

=pod

=encoding utf8

=head1 Name

App::MCP::Exception - One-line description of the modules purpose

=head1 Synopsis

   use App::MCP::Exception;
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
