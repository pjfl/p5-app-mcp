package App::MCP::API::Event;

use App::MCP::Constants   qw( EXCEPTION_CLASS NUL TRUE );
use HTTP::Status          qw( HTTP_BAD_REQUEST HTTP_CREATED
                              HTTP_NOT_FOUND HTTP_OK );
use Unexpected::Types     qw( Object );
use App::MCP::Util        qw( trigger_input_handler );
use Unexpexted::Functions qw( throw );
use JSON::MaybeXS         qw( );
use Try::Tiny;
use Moo;

# Private attributes
has '_transcoder' => is => 'lazy', isa => Object,
   builder        => sub { JSON::MaybeXS->new }, reader => 'transcoder';

# TODO: Event api calls parked here. Needs recasting
# Public methods
sub create_event {
   my ($self, $req) = @_; my $event; $req->authenticate_headers;

   my $schema = $self->schema;
   my $run_id = $req->query_params->( 'runid' );
   my $pe_rs  = $schema->resultset( 'ProcessedEvent' )
                       ->search( { runid   => $run_id },
                                 { columns => [ 'token' ] } );
   my $pevent = $pe_rs->first
     or throw 'Runid [_1] not found', [ $run_id ], rv => HTTP_NOT_FOUND;
   my $params = $self->authenticate_params
      ( $run_id, $pevent->token, $req->body_params->( 'event' ) );

   try    { $event = $schema->resultset( 'Event' )->create( $params ) }
   catch  { throw $_, rv => HTTP_BAD_REQUEST };

   trigger_input_handler $self->config->appclass->env_var( 'DAEMON_PID' );

   return { code    => HTTP_CREATED,
            content => { message => 'Event '.$event->id.' created' },
            view    => 'json', };
}

sub create_job {
   my ($self, $req) = @_; my $job; $req->authenticate_headers;

   my $sess_id = $req->query_params->( 'sessionid' );
   my $sess    = $self->get_session( $sess_id );
   my $params  = $self->authenticate_params
      ( $sess->{key}, $sess->{shared_secret}, $req->body_params->( 'job' ) );

   $params->{owner_id} = $sess->{user_id};
   $params->{group_id} = $sess->{role_id};

   try    { $job = $self->schema->resultset( 'Job' )->create( $params ) }
   catch  { throw $_, rv => HTTP_BAD_REQUEST };

   return { code    => HTTP_CREATED,
            content => { message => 'Job '.$job->id.' created' },
            view    => 'json', };
}

sub exception_handler {
   my ($self, $req, $e) = @_; my $msg = "${e}"; chomp $msg;

   return { code => $e->rv, content => { message => $msg }, view => 'json', };
}

use namespace::autoclean;

1;
