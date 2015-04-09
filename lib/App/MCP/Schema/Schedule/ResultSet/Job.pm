package App::MCP::Schema::Schedule::ResultSet::Job;

use strictures;
use parent 'DBIx::Class::ResultSet';

use App::MCP::Constants    qw( FALSE TRUE );
use Class::Usul::Functions qw( first_char throw );
use HTTP::Status           qw( HTTP_NOT_FOUND );

# Private methods
my $_get_job_state = sub {
   my ($self, $fqjn) = @_;

   my $job = $self->search( { fqjn => $fqjn }, { prefetch => 'state' } )->single
      or throw 'Job [_1] unknown', [ $fqjn ];

   return $job->state ? $job->state->name : 'inactive';
};

# Public methods
sub assert_executable {
   my ($self, $fqjn, $user) = @_; my $job = $self->find_by_name( $fqjn );

   $job->is_executable_by( $user->id )
        or throw 'Job [_1] execute permission denied to [_2]',
                 [ $fqjn, $user->username ];

   return $job;
}

sub dump {
   my ($self, $job_spec) = @_; my $index = {}; my @jobs;

   my $rs = $self->search( {
      fqjn => { like => $job_spec }, }, {
         order_by     => 'id',
         result_class => 'DBIx::Class::ResultClass::HashRefInflator',
      } );

   for my $job ($rs->all) {
      delete $job->{group}; delete $job->{owner}; delete $job->{parent_path};
      $index->{ delete $job->{id} } = $job->{fqjn};

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
   my ($self, $fqjn) = @_;

   my $job = $self->search( { fqjn => $fqjn } )->single
      or throw 'Job [_1] unknown', [ $fqjn ], rv => HTTP_NOT_FOUND;

   return $job;
}

sub finished {
   return $_[ 0 ]->$_get_job_state( $_[ 1 ] ) eq 'finished' ? TRUE : FALSE ;
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

sub job_id_by_name {
   my ($self, $fqjn) = @_;

   my $job = $self->search( { fqjn => $fqjn }, { columns => [ 'id' ] } )->single
      or throw 'Job [_1] unknown', [ $fqjn ];

   return $job->id;
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
