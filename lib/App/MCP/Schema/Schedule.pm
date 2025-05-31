package App::MCP::Schema::Schedule;

use strictures;
use parent 'DBIx::Class::Schema';

use App::MCP; our $VERSION = App::MCP->schema_version;

my $class = __PACKAGE__;

$class->load_namespaces;
$class->load_components('Schema::Versioned');

my $config;

sub config {
   my ($self, $value) = @_;

   $config = $value if defined $value;

   $self->upgrade_directory($config->sqldir->as_string)
      if $self->can('upgrade_directory');

   return $config;
}

sub create_ddl_dir {
   my ($self, @args) = @_;

   local $SIG{__WARN__} = sub {
      my $error = shift;
      warn "${error}\n"
         unless $error =~ m{ Overwriting \s existing \s DDL \s file }mx;
      return 1;
   };

   return $self->SUPER::create_ddl_dir(@args);
}

sub deploy {
   my ($self, $sqltargs, $dir) = @_;

   $self->throw_exception("Can't deploy without storage") unless $self->storage;

   eval {
      $self->storage->_get_dbh->do('DROP TABLE dbix_class_schema_versions');
   };

   $self->storage->deploy($self, undef, $sqltargs, $dir);
   return;
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
