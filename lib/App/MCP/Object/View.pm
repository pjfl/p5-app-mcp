package App::MCP::Object::View;

use HTML::StateTable::Constants qw( FALSE NUL TRUE );
use HTML::StateTable::Types     qw( ArrayRef Int ResultRole Str Table Undef );
use Class::Usul::Cmd::Util      qw( ensure_class_loaded );
use JSON::MaybeXS               qw( encode_json );
use List::Util                  qw( pairs );
use Ref::Util                   qw( is_arrayref is_coderef is_plain_hashref );
use Data::Page;
use Moo;
use MooX::HandlesVia;

=item count

Synonym for C<total_results>

=cut

has 'count' => is => 'lazy', isa => Int, default => sub { shift->total_results};

# This is the current index into the results list for the iterator
has '_index' => is => 'rw', isa => Int, lazy => TRUE, default => 0;

# The list of results which will be displayed in response to this request
has '_results' =>
   is          => 'lazy',
   isa         => ArrayRef[ResultRole|Undef],
   builder     => 'build_results',
   handles_via => 'Array',
   handles     => { result_count => 'count' },
   clearer     => '_clear_results';

=item result_class

=cut

has 'result_class' =>
   is      => 'ro',
   isa     => Str,
   default => 'App::MCP::Object::Result';

=item table

Required weak reference to the table object

=cut

has 'table' => is => 'ro', isa => Table, required => TRUE, weak_ref => TRUE;

=item total_results

The total number of objects in the resultset

=cut

has 'total_results' =>
   is      => 'lazy',
   isa     => Int,
   writer  => '_set_total_results',
   default => sub { shift->result_count };

=item build_results

Returns a reference to an array of L<MCat::Object::Result> objects

=cut

sub build_results {
   my $self         = shift;
   my $results      = [];
   my $table        = $self->table;
   my $source       = $table->result->result_source;
   my $result_class = $self->result_class;

   ensure_class_loaded $result_class;

   for my $colname ($source->columns) {
      my $info = $source->columns_info->{$colname};

      next if $info->{hidden};

      my $accessor = $info->{accessor} // $colname;
      my $value;

      if (my $display = $info->{display}) {
         if (is_coderef $display) { $value = $display->($table) }
         else {
            $value = $table->result;

            for my $component (split m{ \. }mx, $display) {
               if ($value) { $value = $value->$component }
               else {
                  # TODO: Log warn
                  $value = NUL;
                  last;
               }
            }
         }
      }
      else { $value = $table->result->$accessor }

      if (is_arrayref $value or is_plain_hashref $value) {
         $value = encode_json($value);
      }

      my $traits = $info->{cell_traits} // [];
      my $name   = $info->{label} // ucfirst $colname;

      push @{$results}, $result_class->new(
         cell_traits => $traits, name => $name, value => $value
      );
   }

   if ($table->can('has_add_columns') && $table->has_add_columns) {
      for my $pair (pairs @{$table->add_columns}) {
         my $value = $pair->value;

         if (is_arrayref $value or is_plain_hashref $value) {
            $value = encode_json($value);
         }

         push @{$results}, $result_class->new(
            name => $pair->key, value => $value
         );
      }
   }

   return $results;
}

=item next

This is the iterator call to return the next result object

=cut

sub next {
   my $self = shift;

   return if $self->_index >= $self->total_results;

   my $result = $self->_results->[$self->_index];

   $self->_index($self->_index + 1);

   return $result;
}

=item pager

Provides L<HTML::StateTable> with a L<Data::Page> object

=cut

sub pager {
   my $self = shift;

   return Data::Page->new(
      $self->total_results, $self->total_results, 1
   );
}

=item reset

Resets the iterators state whenever one of the request parameters changes

=cut

sub reset {
   my $self = shift; $self->_index(0); return $self;
}

=item result_source

Required by L<HTML::StateTable>

=cut

sub result_source {
   return shift;
}

=item search( where, options )

Required by L<HTML::StateTable>. Does nothing, just returns self

=cut

sub search {
   my ($self, $where, $options) = @_; return $self;
}

use namespace::autoclean;

1;
