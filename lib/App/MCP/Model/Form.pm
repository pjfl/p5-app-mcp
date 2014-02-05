package App::MCP::Model::Form;

use namespace::sweep;

use Moo;
use App::MCP::Constants;
use App::MCP::Functions    qw( get_or_throw );
use Class::Usul::Functions qw( throw );
use HTTP::Status           qw( HTTP_EXPECTATION_FAILED );
use Unexpected::Functions  qw( Unspecified );

extends q(App::MCP::Model);
with    q(App::MCP::Role::CommonLinks);
with    q(App::MCP::Role::JavaScript);
with    q(App::MCP::Role::PageConfiguration);
with    q(App::MCP::Role::Preferences);
with    q(App::MCP::Role::FormBuilder);

# Public methods
sub job {
   my ($self, $req) = @_; my $id = $req->args->[ 0 ];

   my $title = $req->loc( 'Job Definition' );
   my $page  = { action => $req->uri, form_name => 'job', title => $title, };
   my $job   = $id ? $self->schema->resultset( 'Job' )->find( $id ) : undef;

   return $self->get_stash( $req, $page, job => $job );
}

sub job_choose {
   my ($self, $req) = @_;

   my $job      = $self->schema->resultset( 'Job' )->search( {
      name => $req->body->param->{name} }, { columns => [ 'id' ] } )->first;
   my $location = $req->uri_for( 'job', [ $job ? $job->id : undef ] );

   return { redirect => { location => $location } };
}

sub job_chooser {
   my ($self, $req) = @_;

   my $chooser = $self->build_chooser( $req );
   my $page    = { meta => delete $chooser->{meta} };

   return $self->get_stash( $req, $page, 'job_chooser' => $chooser );
}

sub job_clear {
   return { redirect => { location => $_[ 1 ]->uri_for( 'job' ) } };
}

sub job_delete {
   my ($self, $req) = @_;

   my $id       = $req->args->[ 0 ]
      or throw class => Unspecified, args => [ 'id' ],
                  rv => HTTP_EXPECTATION_FAILED;
   my $location = $req->uri_for( 'job' );
   my $message  = [ 'Job id [_1] not found', $id ];
   my $job      = $self->schema->resultset( 'Job' )->find( $id )
      or return { redirect => { location => $location, message => $message } };
   my $fqjn     = $job->fqjn; $job->delete;

   $message     = [ 'Job name [_1] deleted', $fqjn ];

   return { redirect => { location => $location, message => $message } };
}

sub job_grid_rows {
   my ($self, $req) = @_; my $params = $req->params;

   $params->{form  } = 'job';
   $params->{method} = '_job_chooser_link_hash';
   $params->{values} = $self->_job_chooser_search( $params );

   my $grid_rows = $self->build_grid_rows( $req );
   my $page      = { meta => delete $grid_rows->{meta} };

   return $self->get_stash( $req, $page, 'job_grid_rows' => $grid_rows );
}

sub job_grid_table {
   my ($self, $req) = @_; my $params = $req->params;

   my $field_value  = get_or_throw( $params, 'field_value' );

   $params->{form } = 'job';
   $params->{label} = 'Job names';
   $params->{total} = $self->schema->resultset( 'Job' )
                           ->search( { name => { -like => $field_value } } )
                           ->count;

   my $grid_table = $self->build_grid_table( $req );
   my $page       = { meta => delete $grid_table->{meta} };

   return $self->get_stash( $req, $page, 'job_grid_table' => $grid_table );
}

sub job_save {
   my ($self, $req) = @_; my $id; my $job; my $message;

   my $args = { deflate => \&_job_deflator,
                param   => $req->body->param,
                rs      => $self->schema->resultset( 'Job' ) };

   if ($id = $req->args->[ 0 ]) {
      $job     = $self->find_and_update_record( $args, $id ) or return {
         redirect => { location => $req->uri_for( 'job' ),
                       message  => [ 'Job id [_1] not found', $id ] } };
      $message = [ 'Job name [_1] updated', $job->fqjn ];
   }
   else {
      $job     = $self->create_record( $args );
      $message = [ 'Job name [_1] created', $job->fqjn ];
   }

   my $location = $req->uri_for( 'job', [ $job->id ] );

   return { redirect => { location => $location, message => $message } };
}

sub state_diagram {
   return $_[ 0 ]->get_stash( $_[ 1 ], { title => 'State Diagram' } );
}

# Private methods
sub _job_chooser_href {
   my ($self, $req) = @_; return $req->uri_for( 'job_chooser' );
}

sub _job_chooser_link_hash {
   my ($self, $req, $link_num, $job) = @_;

   my $tip = $req->loc( 'Click to select this job' );

   return { href => '#top', text => $job->name, tip => $tip, };
}

sub _job_chooser_search {
   my ($self, $params) = @_;

   my $field_value = get_or_throw( $params, 'field_value' );
   my $page        = get_or_throw( $params, 'page'        );
   my $page_size   = get_or_throw( $params, 'page_size'   );

   return [ $self->schema->resultset( 'Job' )->search
            ( { name     => { -like => $field_value } },
              { order_by => 'name',
                page     => $page + 1,
                rows     => $page_size } )->all ];
}

sub _job_deflator {
   my ($self, $param, $col) = @_;

   $col eq 'crontab' and
      return join SPC, map { $param->{ "crontab_${_}" } } CRONTAB_FIELD_NAMES;

   if ($col eq 'group') {
      my $rs   = $self->schema->resultset( 'Role' );
      my $role = $rs->find_by_name( $param->{ 'group_rel' } // 'unknown' );

      return $role ? $role->id : undef;
   }

   if ($col eq 'owner') {
      my $rs   = $self->schema->resultset( 'User' );
      my $user = $rs->find_by_name( $param->{ 'owner_rel' } // 'unknown' );

      return $user ? $user->id : undef;
   }

   $col eq 'permissions' and return oct( $param->{ $col } // 0 );

   return exists $param->{ $col } ? $param->{ $col } : undef;
}

1;

__END__

=pod

=encoding utf8

=head1 Name

App::MCP::Model::Form - One-line description of the modules purpose

=head1 Synopsis

   use App::MCP::Model::Form;
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
# vim: expandtab shiftwidth=3:
