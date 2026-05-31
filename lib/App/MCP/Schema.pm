package App::MCP::Schema;

use App::MCP::Constants         qw( EXCEPTION_CLASS FALSE NUL SPC TRUE );
use Archive::Tar::Constant      qw( COMPRESS_GZIP );
use Class::Usul::Cmd::Constants qw( AS_PARA AS_PASSWORD COMMA OK QUOTED_RE );
use App::MCP::Util              qw( distname local_config );
use Class::Usul::Cmd::Util      qw( decrypt dump_file encrypt
                                    ensure_class_loaded load_file now_dt trim );
use File::DataClass::IO         qw( io );
use Unexpected::Functions       qw( throw PathNotFound Unspecified );
use Archive::Tar;
use Data::Record;
use Format::Human::Bytes;
use Try::Tiny;
use Moo;
use Class::Usul::Cmd::Options;

extends 'Class::Usul::Cmd';
with    'App::MCP::Role::Config';
with    'App::MCP::Role::Log';

=pod

=encoding utf-8

=head1 Name

App::MCP::Schema - Command line database utility methods

=head1 Synopsis

   #!/usr/bin/env perl

   use App::MCP::Schema;

   exit App::MCP::Schema->new_with_options->run;

=head1 Description

Command line database utility methods

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=item C<admin_password>

Database administration password. Unsed to create the database user and the
schema. This is not stored

=cut

has 'admin_password' =>
   is      => 'lazy',
   default => sub {
      my $self     = shift;
      my $password = $self->get_line('+Enter DB admin password', AS_PASSWORD);

      throw Unspecified, ['admin password'] unless $password;

      return $ENV{PGPASSWORD} = $password;
   };

=item C<config_extension>

Defaults to C<.json>. The expected format of the files used to populate the
schema when it is created

=cut

has 'config_extension' => is => 'ro', default => '.json';

=item C<db_password>

This should be in the local configuration file. See C<store_password>

=cut

has 'db_password' =>
   is      => 'lazy',
   default => sub {
      my $self     = shift;
      my $password = local_config($self->config)->{db_password};

      throw Unspecified, ['db_password'] unless $password;

      return decrypt NUL, $password;
   };

=item C<deploy_classes>

Defaults to the C<schema_class>. This is used to select the files that will
populate the schema when it is created

=cut

has 'deploy_classes' =>
   is      => 'ro',
   default => sub { [shift->config->schema_class] };

=item C<host>

Defaults to C<localhost>

=cut

has 'host' => is => 'ro', default => 'localhost';

=item C<producers>

A hash reference keyed by DSN driver names

=cut

has 'producers' =>
   is      => 'ro',
   default => sub {
      return { mysql => 'MySQL', pg => 'PostgreSQL', sqlite => 'SQLite' };
   };

=item C<schema>

An instance of L<DBIx::Class::Schema>

=cut

has 'schema' =>
   is      => 'lazy',
   default => sub {
      my $self  = shift;
      my $class = $self->config->schema_class;
      my $info  = [ @{$self->config->connect_info} ];

      $info->[3] = _connect_attr();

      my $schema = $class->connect(@{$info});

      $class->config($self->config) if $class->can('config');

      return $schema;
   };

=item C<user_name>

Defaults from configuration to the application prefix C<mcp>

=cut

has 'user_name' => is => 'lazy', default => sub { shift->config->prefix };

=item C<user_password>

This should be in the local configuration file. See C<store_password>

=cut

has 'user_password' =>
   is      => 'lazy',
   default => sub {
      my $self     = shift;
      my $name     = $self->user_name;
      my $password = local_config($self->config)->{"${name}_password"};

      throw Unspecified, ["${name} password"] unless $password;

      return decrypt NUL, $password;
   };

# Private attributes
has '_dbname' =>
   is      => 'lazy',
   default => sub {
      my $self = shift;
      my $dbname;

      if ($self->config->db_dsn =~ m{ dbname[=] }mx) {
         $dbname = (map  { s{ \A dbname [=] }{}mx; $_ }
                    grep { m{ \A dbname [=] }mx }
                    split  m{           [:] }mx, $self->config->db_dsn)[0];
      }

      return $dbname;
   };

has '_ddl_path' =>
   is      => 'lazy',
   default => sub {
      my $self    = shift;
      my $schema  = $self->schema;
      my $type    = $self->_type;
      my $version = $schema->schema_version;
      my $dir     = $self->config->sqldir;

      return io($schema->ddl_filename($type, $version, $dir));
   };

has '_driver' =>
   is      => 'lazy',
   default => sub {
      my $self   = shift;
      my $driver = (split m{ : }mx, $self->config->db_dsn)[1];

      return lc $driver;
   };

has '_host' =>
   is      => 'lazy',
   default => sub {
      my $self = shift;
      my $host = $self->host;

      unless ($self->options && $self->options->{bootstrap}) {
         if ($self->config->db_dsn =~ m{ host[=] }mx) {
            $host = (map  { s{ \A host [=] }{}mx; $_ }
                     grep { m{ \A host [=] }mx }
                     split  m{         [;] }mx, $self->config->db_dsn)[0];
         }
      }

      return $host;
   };

has '_type' =>
   is      => 'lazy',
   default => sub {
      my $self = shift;

      return $self->producers->{$self->_driver};
   };

=back

=head1 Subroutines/Methods

Defines the following methods;

=over 3

=item C<BUILD>

Does nothing

=cut

sub BUILD {}

=item C<backup> - Backs up the database

Backs up the database

=cut

sub backup : method {
   my $self = shift;
   my $now  = now_dt;
   my $db   = $self->_dbname;
   my $date = $now->ymd(NUL) . '-' . $now->hms(NUL);
   my $file = "${db}-${date}.sql";
   my $conf = $self->config;
   my $path = $conf->tempdir->catfile($file);
   my $bdir = $conf->vardir->catdir('backup');
   my $tarb = "${db}-${date}.tgz";
   my $out  = $bdir->catfile($tarb)->assert_filepath;

   ensure_class_loaded 'Archive::Tar';
   $self->info('Generating backup [_1]', { args => [$tarb] });
   $self->_create_ddl_file;
   $self->run_cmd($self->_backup_command($path));
   chdir $conf->home;

   my $arc = Archive::Tar->new;

   $self->_add_backup_files($arc);

   $arc->add_files($path->abs2rel($conf->home)) if $path->exists;

   $arc->write($out->pathname, COMPRESS_GZIP);
   $path->unlink;
   $file = $out->basename;

   my $size = Format::Human::Bytes->new()->base2($out->stat->{size});
   my $opts = { args => [$file, $size] };

   $self->info('Backup complete. File [_1] size [_2]', $opts);
   return OK;
}

=item C<dump_jobs> - Dump selected job definitions to a file

The default dump file name is C<jobs.json>

=cut

sub dump_jobs : method {
   my $self     = shift;
   my $job_spec = $self->next_argv // '%';
   my $file     = $self->next_argv // 'jobs.json';
   my $path     = $self->config->vardir->catdir('share')->catfile($file);
   my $data     = $self->schema->resultset('Job')->dump($job_spec);
   my $count    = @{ $data };
   my $args     = [$count, $job_spec, $path];

   dump_file($path, { jobs => $data });

   $self->info("Dumped [_1] jobs matching '[_2]' to '[_3]'", { args => $args });
   return OK;
}

=item C<install> - Creates the database and deploys the schema

Creates the database and deploys the schema

=cut

sub install : method {
   my $self = shift;
   my $text = 'Schema creation requires a database, id and password. '
            . 'For Postgres the driver is Pg and the port 5432. For '
            . 'MySQL the driver is mysql and the port 3306';

   $self->output($text, AS_PARA);
   $self->yorn('+Create database', TRUE, TRUE, 0) or return OK;
   $self->admin_password;
   $self->_store_password('db');
   $self->_drop_database;
   $self->_drop_user;
   $self->_create_user;
   $self->_create_database;
   $self->_deploy_and_populate_classes;
   return OK;
}

=item C<load_jobs> - Load job table dump file

The default load file name is C<jobs.json>

=cut

sub load_jobs : method {
   my $self  = shift;
   my $file  = $self->next_argv // 'jobs.json';
   my $path  = $self->config->vardir->catdir('share')->catfile($file);
   my $data  = load_file($path);
   my $rs    = $self->schema->resultset('Job');
   my $count = $rs->load($self->_authenticate_user, $data->{jobs});

   $self->info("Loaded [_1] jobs from [_2]", { args => [$count, $path] });
   return OK;
}

=item C<restore> - Restores the database from a backup

Restores the database from a backup

=cut

sub restore : method {
   my $self = shift;
   my $conf = $self->config;
   my $path = $self->next_argv or throw Unspecified, ['file name'];

   $path = io $path;
   throw PathNotFound, [$path] unless $path->exists;
   ensure_class_loaded 'Archive::Tar';

   my $arc = Archive::Tar->new;

   chdir $conf->home;
   $arc->read($path->pathname);
   $arc->extract();

   my $db   = $self->_dbname;
   my $file = $path->basename('.tgz');
   my (undef, $date) = split m{ - }mx, $file, 2;
   my $sql  = $conf->tempdir->catfile("${db}-${date}.sql");

   if ($sql->exists) {
      $self->run_cmd($self->_restore_command($sql));
      $sql->unlink;
   }

   my $ver = $self->schema->get_db_version;

   $self->info('Restored backup [_1] schema [_1]', { args => [$file, $ver] });

   return OK;
}

=item C<store_password> - Stores application users passwords

Defaults to storing the password for the application user. Can also store the
database user password by setting the next command line argument to C<db>

It will write an encrypted copy of the password to the local
configuration file

=cut

sub store_password : method {
   my $self = shift;

   $self->_store_password($self->next_argv // 'db');

   return OK;
}

# Private functions
sub _connect_attr () {
   return {
      AutoCommit        => TRUE,
      PrintError        => FALSE,
      RaiseError        => TRUE,
      add_drop_table    => TRUE,
      ignore_version    => TRUE,
      no_comments       => TRUE,
      quote_identifiers => TRUE,
   };
}

sub _unquote ($) {
   local $_ = $_[0]; s{ \A [\'\"] }{}mx; s{ [\'\"] \z }{}mx; return $_;
}

# Private methods
sub _add_backup_files {
   my ($self, $arc) = @_;

   my $conf = $self->config;

   for my $file (map { io $_ } $conf->local_config_file) {
      $arc->add_files($file->abs2rel($conf->home));
   }

   $arc->add_files($self->_ddl_path->abs2rel($conf->home));
   return;
}

sub _authenticate_user {
   my $self     = shift;
   my $username = $self->user_name;
   my $user_rs  = $self->schema->resultset('User');
   my $user     = $user_rs->authenticate($username, $self->user_password);
   my $leader   = 'Schema.authenticate_user';

   $self->log->debug("${leader}: User ${username} authenticated");

   return { user => $user, groups => $user->groups };
}

sub _backup_command {
   my ($self, $path) = @_;

   my $dbname = $self->_dbname;
   my $host   = $self->_host;
   my $user   = $self->config->db_username;
   my $driver = $self->_driver;
   my $cmd;

   if ($driver eq 'pg') {
      $ENV{PGPASSWORD} = $self->db_password;
      $cmd = "pg_dump --file=${path} -h ${host} -U ${user} ${dbname}";
   }

   throw 'No backup command for driver [_1]', [$driver] unless $cmd;

   return $cmd;
}

sub _create_database {
   my $self   = shift;
   my $dbname = $self->_dbname;
   my $host   = $self->_host;
   my $user   = $self->config->db_username;
   my $driver = $self->_driver;
   my $cmd;

   if ($driver eq 'pg') {
      my $sql =
         "create database ${dbname} owner ${user} encoding 'UTF8'; " .
         "alter database ${dbname} set TIMEZONE = 'UTC'; " .
         "create extension if not exists tablefunc;";

      $cmd = qq{psql -h ${host} -q -t -U postgres -w -c "${sql}"};
   }

   throw 'No create database command for driver [_1]', [$driver] unless $cmd;

   return $self->run_cmd($cmd, { out => 'stdout' });
}

sub _create_ddl_file {
   my $self    = shift;
   my $schema  = $self->schema;
   my $type    = $self->_type;
   my $version = $schema->schema_version;
   my $dir     = $self->config->sqldir;

   $schema->create_ddl_dir($type, $version, $dir);
   return;
}

sub _create_user {
   my $self    = shift;
   my $host    = $self->_host;
   my $dbname  = $self->_dbname;
   my $user    = $self->config->db_username;
   my $upasswd = $self->db_password;
   my $driver  = $self->_driver;
   my $cmd;

   throw 'Must set a user password' unless length $upasswd;

   if ($driver eq 'pg') {
      my $sql = "create role ${user} with login password '${upasswd}';";

      $cmd = qq{psql -h ${host} -q -t -U postgres -w -c "${sql}"};
   }

   throw 'No create user command for driver [_1]', [$driver] unless $cmd;

   return $self->run_cmd($cmd, { out => 'stdout' });
}

sub _deploy_and_populate_classes {
   my $self = shift;
   my $dir  = $self->config->sqldir;

   my $result_objects;

   for my $schema_class (@{$self->deploy_classes}) {
      $self->info('Deploy and populate [_1]', {
         args => [$schema_class], leader => 'Admin.deploy' }
      );
      $self->yorn('+Continue', TRUE, TRUE, 0) or next;
      ensure_class_loaded $schema_class;
      $schema_class->config($self->config) if $schema_class->can('config');
      $self->info('Deploying schema [_1] and populating', {
         args => [$schema_class], leader => 'Admin.deploy' }
      );
      $result_objects = $self->_deploy_and_populate($schema_class, $dir);
   }

   return;
}

sub _deploy_and_populate {
   my ($self, $schema_class, $dir) = @_;

   my $schema = $self->schema;

   $schema->storage->ensure_connected;
   $schema->deploy(_connect_attr, $dir);

   my $split = Data::Record->new({ split => COMMA, unless => QUOTED_RE });
   my $res;

   for my $tuple (@{$self->_list_population_classes($schema_class, $dir)}) {
      $res->{$tuple->[0]} = $self->_populate_class($schema, $split, @{$tuple});
   }

   return $res;
}

sub _drop_database {
   my $self   = shift;
   my $dbname = $self->_dbname;
   my $host   = $self->_host;
   my $driver = $self->_driver;
   my $cmd;

   if ($driver eq 'pg') {
      my $sql = "drop database if exists ${dbname};";

      $cmd = qq{psql -h ${host} -q -t -U postgres -w -c "${sql}"};
   }

   throw 'No drop database command for driver [_1]', [$driver] unless $cmd;

   return $self->run_cmd($cmd, { out => 'stdout' });
}

sub _drop_user {
   my $self   = shift;
   my $host   = $self->_host;
   my $user   = $self->config->db_username;
   my $driver = $self->_driver;
   my $cmd;

   if ($driver eq 'pg') {
      my $sql = "drop user if exists ${user};";

      $cmd = qq{psql -h ${host} -q -t -U postgres -w -c "${sql}"};
   }

   throw 'No drop user command for driver [_1]', [$driver] unless $cmd;

   my $output = $self->run_cmd($cmd, { expected_rv => 1, out => 'buffer' });

   $self->dumper($output) if $self->debug;
   return;
}

sub _list_population_classes {
   my ($self, $schema_class, $dir) = @_;

   my $dist = distname $schema_class;
   my $extn = $self->config_extension;
   my $re   = qr{ \A $dist [-] \d+ [-] (.*) \Q$extn\E \z }mx;
   my $io   = io($dir)->filter(sub { $_->filename =~ $re });
   my $res  = [];

   for my $path ($io->all_files) {
      my ($class) = $path->filename =~ $re;

      push @{$res}, [$class, $path];
   }

   return $res;
}

sub _populate_class {
   my ($self, $schema, $split, $class, $path) = @_;

   unless ($class) {
      $self->fatal('No class in [_1]', {
         args => [$path->filename], leader => 'Admin._populate_class'
      });
   }

   $self->output("Populating ${class}");

   my $data   = load_file($path) // {};
   my $fields = [split SPC, $data->{fields}];
   my @rows   = map { [ map { _unquote(trim $_) } $split->records($_) ] }
                   @{ $data->{rows} };
   my $res;

   try   { $res = $schema->populate($class, [$fields, @rows]) }
   catch {
      if ($_->can('class') and $_->class eq 'ValidationErrors') {
         $self->warning("${_}") for (@{$_->args});
      }

      throw $_;
   };

   return $res;
}

sub _restore_command {
   my ($self, $sql) = @_;

   my $host   = $self->_host;
   my $user   = $self->config->db_username;
   my $driver = $self->_driver;
   my $cmd;

   if ($driver eq 'pg') {
      $ENV{PGPASSWORD} = $self->db_password;
      $cmd = "pg_restore -C -d postgres -h ${host} -U ${user} ${sql}";
   }

   throw 'No restore command for driver [_1]', [$driver] unless $cmd;

   return $cmd;
}

sub _store_password {
   my ($self, $username) = @_;

   my $password = $self->get_line("+Enter ${username} password", AS_PASSWORD);
   my $again    = $self->get_line("+Again", AS_PASSWORD);

   throw 'Passwords do no match' unless $password eq $again;

   my $data = local_config($self->config);

   $data->{"${username}_password"} = encrypt NUL, $password;
   local_config($self->config, $data);

   my $options = { leader => 'Schema.store_password' };

   $self->info("Updated ${username} password", $options);
   return;
}

use namespace::autoclean;

1;

__END__

=back

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Class::Usul::Cmd>

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

Peter Flanigan, C<< <pjfl@cpan.org> >>

=head1 License and Copyright

Copyright (c) 2025 Peter Flanigan. All rights reserved

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
