package App::MCP::Schema;

use namespace::autoclean;

use Moo;
use App::MCP;
use App::MCP::Constants    qw( EXCEPTION_CLASS OK );
use App::MCP::Functions    qw( qualify_job_name trigger_input_handler );
use Class::Usul::Functions qw( throw );
use Class::Usul::Options;
use Class::Usul::Types     qw( LoadableClass NonEmptySimpleStr Object );
use Unexpected::Functions  qw( Unspecified );

extends q(Class::Usul::Schema);
with    q(App::MCP::Worker::Role::UserPassword);

our $VERSION          = App::MCP->VERSION;
my ($schema_version)  = $VERSION =~ m{ (\d+\.\d+) }mx;

# Public attributes (visible to the command line)
option 'role_name'    => is => 'ro',   isa => NonEmptySimpleStr,
   documentation      => 'Name in the role table',
   default            => 'unknown', format => 's', short => 'r';

option 'user_name'    => is => 'ro',   isa => NonEmptySimpleStr,
   documentation      => 'Name in the user table and .mcprc file',
   default            => 'unknown', format => 's', short => 'u';

# Public attributes (override defaults in base class)
has '+config_class'   => default => 'App::MCP::Config';

has '+database'       => default => sub { $_[ 0 ]->config->database };

has '+schema_classes' => default => sub { $_[ 0 ]->config->schema_classes };

has '+schema_version' => default => $schema_version;

# Private attributes
has '_schedule'       => is => 'lazy', isa => Object, builder => sub {
   my $self = shift; my $extra = $self->config->connect_params;
   $self->schedule_class->connect( @{ $self->connect_info }, $extra ) },
   reader             => 'schedule';

has '_schedule_class' => is => 'lazy', isa => LoadableClass,
   builder            => sub { $_[ 0 ]->schema_classes->{ 'mcp-model' } },
   reader             => 'schedule_class';

# Private methods
my $_authenticated_user_info = sub {
   my $self    = shift;
   my $info    = {};
   my $schema  = $self->schedule;
   my $user_rs = $schema->resultset( 'User' );
   my $user    = $info->{user} = $user_rs->find_by_name( $self->user_name );
   my $log     = $self->log;

   $user->authenticate( $self->get_user_password( $user->username ) );
   $log->debug( 'User '.$user->username.' authenticated' );

   my $role_rs = $schema->resultset( 'Role' );
   my $role    = $info->{role} = $role_rs->find_by_name( $self->role_name );

   $user->assert_member_of( $role );
   return $info;
};

# Public methods
sub dump_jobs : method {
   my $self     = shift;
   my $job_spec = $self->next_argv || '%';
   my $path     = $self->next_argv || 'jobs.json';
   my $data     = $self->schedule->resultset( 'Job' )->dump( $job_spec );
   my $count    = @{ $data };

   $self->file->data_dump( data => { jobs => $data }, path => $path, );
   $self->info( "Dumped [_1] jobs matching '[_2]' to '[_3]'",
                { args => [ $count, $job_spec, $path ] } );
   return OK;
}

sub load_jobs : method {
   my $self     = shift;
   my $path     = $self->next_argv || 'jobs.json';
   my $data     = $self->file->data_load( paths => [ $path ] );
   my $rs       = $self->schedule->resultset( 'Job' );
   my $count    = $rs->load( $self->$_authenticated_user_info, $data->{jobs} );

   $self->info( "Loaded [_1] jobs from '[_2]'", { args => [ $count, $path ] } );
   return OK;
}

sub send_event : method {
   my $self     = shift;
   my $job_name = $self->next_argv or throw Unspecified, [ 'job name' ];
   my $trans    = $self->next_argv || 'start';
   my $fqjn     = qualify_job_name $job_name;
   my $schema   = $self->schedule;
   my $job_rs   = $schema->resultset( 'Job' );
   my $event_rs = $schema->resultset( 'Event' );
   my $user     = $self->$_authenticated_user_info->{user};
   my $job      = $job_rs->assert_executable( $fqjn, $user );

   $event_rs->create( { job_id => $job->id, transition => $trans } );

   my $pid_file = $self->config->rundir->catfile( 'daemon.pid' );

   $pid_file->exists and trigger_input_handler $pid_file->chomp->getline;
   $self->info( "Job '[_1]' was sent a [_2] event",
                { args => [ $fqjn, $trans ] } );
   return OK;
}

sub set_client_password : method {
   $_[ 0 ]->set_user_password( @{ $_[ 0 ]->extra_argv } ); return OK;
}

1;

__END__

=pod

=head1 Name

App::MCP::Schema - <One-line description of module's purpose>

=head1 Synopsis

   use App::MCP::Schema;
   # Brief but working code examples

=head1 Description

=head1 Configuration and Environment

=head1 Subroutines/Methods

=head2 dump_jobs - Dump selected job definitions to a file

=head2 load_jobs - Load job table dump file

=head2 send_event - Create a job state transition event

=head2 set_client_password - Set the MCP user client side password

=head1 Diagnostics

=head1 Dependencies

=over 3

=item L<Class::Usul>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module.
Please report problems to the address below.
Patches are welcome

=head1 Acknowledgements

Larry Wall - For the Perl programming language

=head1 Author

Peter Flanigan, C<< <Support at RoxSoft dot co dot uk> >>

=head1 License and Copyright

Copyright (c) 2014 Peter Flanigan. All rights reserved

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
