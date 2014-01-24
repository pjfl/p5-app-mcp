# @(#)Ident: JavaScript.pm 2014-01-24 14:32 pjf ;

package App::MCP::Role::JavaScript;

use namespace::sweep;

use Class::Usul::Types qw( ArrayRef );
use File::DataClass::IO;
use Moo::Role;

requires qw( config get_stash );

has '_javascripts' => is => 'ro', isa => ArrayRef, builder => sub {
   my $self  = shift;
   my $match = sub { m{ \b \d+ [_] .+? \.js \z }mx };
   my $dir   = $self->config->root->catdir( $self->config->js );

   return [ map { $_->filename } io( $dir )->filter( $match )->all ];
};

around 'get_stash' => sub {
   my ($orig, $self, @args) = @_; my $stash = $orig->( $self, @args );

   $stash->{scripts} = [ @{ $self->_javascripts } ];
   return $stash;
};

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
