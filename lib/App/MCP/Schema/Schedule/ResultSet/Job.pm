package App::MCP::Schema::Schedule::ResultSet::Job;

use strictures;
use parent 'DBIx::Class::ResultSet';

use App::MCP::Constants    qw( FALSE NUL SEPARATOR TRUE );
use Class::Usul::Functions qw( throw );
use HTTP::Status           qw( HTTP_NOT_FOUND );

# Private methods
my $_get_job_state = sub {
   my ($self, $name) = @_;

   my $job = $self->search( { 'me.name' => $name }, {
      prefetch => 'state' } )->single or throw 'Job [_1] unknown', [ $name ];

   return $job->state ? $job->state->name : 'inactive';
};

# Public methods
sub assert_executable {
   my ($self, $name, $user) = @_; my $job = $self->find_by_name( $name );

   $job->is_executable_by( $user->id )
        or throw 'Job [_1] execute permission denied to [_2]',
                 [ $name, $user->username ];

   return $job;
}

sub create {
   my ($self, $col_data) = @_;

   my $prefix      = NUL;
   my $sep         = SEPARATOR;
   my $name        = delete $col_data->{name};
   my $parent_name = delete $col_data->{parent_name};

   defined $parent_name and length $parent_name
       and $prefix = (not $col_data->{type} or $col_data->{type} eq 'job')
                   ? $parent_name.$sep
                   : ((split m{ $sep }mx, $parent_name)[ 0 ]).$sep;

   $col_data->{name} = defined $name ? $prefix.$name : NUL;

   $parent_name and $col_data->{parent_id}
      = $self->writable_box_id_by_name( $parent_name, $col_data->{owner} );
   $col_data->{parent_id} //= 1;

   return $self->next::method( $col_data );
}

sub dump {
   my ($self, $job_spec) = @_; my $index = {}; my @jobs;

   my $rs = $self->search( {
      name => { like => $job_spec }, }, {
         order_by     => 'id',
         result_class => 'DBIx::Class::ResultClass::HashRefInflator',
      } );

   for my $job ($rs->all) {
      delete $job->{group}; delete $job->{owner}; delete $job->{parent_path};
      $index->{ delete $job->{id} } = $job->{name};

      my $parent_id; $parent_id = delete $job->{parent_id}
         and $job->{parent_name} = $index->{ $parent_id };

      push @jobs, $job;
   }

   return \@jobs;
}

sub find_by_id_or_name {
   my ($self, $arg) = @_; (defined $arg and length $arg) or return; my $job;

   $arg =~ m{ \A \d+ }mx and $job = $self->find( $arg );
   $job or $job = $self->find_by_name( $arg );
   return $job;
}

sub find_by_name {
   my ($self, $name) = @_;

   my $job = $self->search( { name => $name } )->single
      or throw 'Job [_1] unknown', [ $name ], rv => HTTP_NOT_FOUND;

   return $job;
}

sub finished {
   return $_[ 0 ]->$_get_job_state( $_[ 1 ] ) eq 'finished' ? TRUE : FALSE ;
}

sub writable_box_id_by_name {
   my ($self, $name, $user_idorn) = @_; my $job = $self->find_by_name( $name );

   $job->type eq 'box' or throw 'Job [_1] is not a box', [ $name ];

   my $user_rs = $self->result_source->schema->resultset( 'User' );
   my $user    = $user_rs->find_by_id_or_name( $user_idorn // 1 );

   $job->is_writable_by( $user->id )
      or throw 'Job [_1] write permission denied to [_1]',
               [ $name, $user->username ];

   return $job->id;
};

sub job_id_by_name {
   my ($self, $name) = @_;

   my $job = $self->search( { name => $name }, { columns => [ 'id' ] } )->single
      or throw 'Job [_1] unknown', [ $name ];

   return $job->id;
}

sub load {
   my ($self, $auth, $jobs) = @_; my $count = 0;

   for my $job (@{ $jobs || [] }) {
      $job->{owner} = $auth->{user}->id; $job->{group} = $auth->{role}->id;
      $self->create( $job );
      $count++;
   }

   return $count;
}

sub predicates {
   return [ qw( finished running terminated ) ];
}

sub running {
   return $_[ 0 ]->$_get_job_state( $_[ 1 ] ) eq 'running' ? TRUE : FALSE
}

sub terminated {
   return $_[ 0 ]->$_get_job_state( $_[ 1 ] ) eq 'terminated' ? TRUE : FALSE;
}

1;

__END__

=pod

=head1 Name

App::MCP::Schema::Schedule::ResultSet::Job - <One-line description of module's purpose>

=head1 Synopsis

   use App::MCP::Schema::Schedule::ResultSet::Job;
   # Brief but working code examples

=head1 Description

=head1 Configuration and Environment

=head1 Subroutines/Methods

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

Copyright (c) 2015 Peter Flanigan. All rights reserved

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
