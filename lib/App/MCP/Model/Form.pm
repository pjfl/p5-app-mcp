package App::MCP::Model::Form;

use namespace::sweep;

use Moo;
use Class::Usul::Constants;
use Class::Usul::Functions qw( throw );
use Data::Validation;
use Unexpected::Functions  qw( Unspecified ValidationErrors );

extends q(App::MCP::Model);
with    q(App::MCP::Role::CommonLinks);
with    q(App::MCP::Role::JavaScript);
with    q(App::MCP::Role::PageConfiguration);
with    q(App::MCP::Role::Preferences);
with    q(App::MCP::Role::FormBuilder);

# Public methods
sub exception_handler {
   my ($self, $req, $e) = @_;

   my $title = $req->loc( 'Exception Handler' );
   my $page  = { code => $e->rv, error => "${e}", title => $title };

   $e->class eq ValidationErrors and $page->{validation_error} = $e->args;

   my $stash = $self->get_stash( $req, $page );

   $stash->{template} = 'exception';
   return $stash;
}

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

sub job_delete {
   my ($self, $req) = @_; my $id = $req->args->[ 0 ];

   my $job      = $self->schema->resultset( 'Job' )->find( $id )
      or throw error => 'Job id [_1] not found', args => [ $id ];
   my $fqjn     = $job->fqjn; $job->delete;
   my $message  = [ 'Job name [_1] deleted', $fqjn ];
   my $location = $req->uri_for( 'job' );

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

   $params->{form } = 'job';
   $params->{label} = 'Job record keys';
   $params->{total} = $self->schema->resultset( 'Job' )
      ->search( { name => { -like => $params->{field_value} } } )->count;

   my $grid_table = $self->build_grid_table( $req );
   my $page       = { meta => delete $grid_table->{meta} };

   return $self->get_stash( $req, $page, 'job_grid_table' => $grid_table );
}

sub job_save {
   my ($self, $req) = @_; my $id; my $job; my $message;

   my $args = { deflate => \&__job_deflator,
                param   => $req->body->param,
                rs      => $self->schema->resultset( 'Job' ) };

   if ($id = $req->args->[ 0 ]) {
      $job     = $self->find_and_update_record( $args, $id )
         or throw error => 'Job id [_1] not found', args => [ $id ];
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
   my ($self, $req, $params, $row, $link_num) = @_;

   my $tip = $req->loc( 'Click to select this job' );

   return { href => '#top', text => $row->name, tip => $tip, };
}

sub _job_chooser_search {
   my ($self, $params) = @_;

   return [ $self->schema->resultset( 'Job' )->search
            ( { name     => { -like => $params->{field_value} } },
              { order_by => 'name',
                page     => $params->{page} + 1,
                rows     => $params->{page_size} } )->all ];
}

# Private functions
sub __get_or_throw {
   my ($params, $name) = @_;

   defined (my $param = $params->{ $name })
      or throw class => Unspecified, args => [ $name ];

   return $param;
}

sub __job_deflator {
   my ($param, $col) = @_;

   if ($col eq 'crontab') {
      return $param->{crontab_min }.SPC.$param->{crontab_hour}.SPC
            .$param->{crontab_mday}.SPC.$param->{crontab_mon }.SPC
            .$param->{crontab_wday}
   }

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
