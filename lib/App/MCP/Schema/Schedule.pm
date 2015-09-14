package App::MCP::Schema::Schedule;

use strictures;
use parent 'DBIx::Class::Schema';

use File::Spec::Functions qw( catfile );
use Scalar::Util          qw( blessed );

__PACKAGE__->load_namespaces;

sub ddl_filename {
    my ($self, $type, $version, $dir, $preversion) = @_;

    $DBIx::Class::VERSION < 0.08100 and ($dir, $version) = ($version, $dir);

   (my $filename = (blessed $self || $self)) =~ s{ :: }{-}gmx;
    $version = join '.', (split m{ [.] }mx, $version)[ 0, 1 ];
    $preversion and $version = "${preversion}-${version}";
    return catfile( $dir, "${filename}-${version}-${type}.sql" );
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
