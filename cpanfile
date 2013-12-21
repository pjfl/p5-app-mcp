requires "Algorithm::Cron" => "0.04";
requires "AnyEvent" => "7.01";
requires "App::MCP::Worker" => "0";
requires "Async::Interrupt" => "1.1";
requires "Authen::HTTP::Signature" => "0.02";
requires "CGI::Simple" => "1.113";
requires "CatalystX::Usul" => "v0.8.0";
requires "Class::C3::Componentised" => "1.001000";
requires "Class::Usul" => "v0.33.0";
requires "Class::Workflow" => "0.11";
requires "Convert::SSH2" => "0.01";
requires "Crypt::Eksblowfish" => "0.009";
requires "DBIx::Class" => "0.08204";
requires "DBIx::Class::Helpers" => "2.016001";
requires "DBIx::Class::InflateColumn::Object::Enum" => "0.04";
requires "DBIx::Class::TimeStamp" => "0.14";
requires "Daemon::Control" => "0.000009";
requires "Data::Record" => "0.02";
requires "Data::Validation" => "v0.11.0";
requires "DateTime" => "0.66";
requires "Exporter::Tiny" => "0.026";
requires "File::DataClass" => "v0.20.0";
requires "HTTP::Message" => "6.06";
requires "IPC::PerlSSH" => "0.16";
requires "JSON" => "2.50";
requires "LWP" => "6.04";
requires "Marpa::R2" => "2.024000";
requires "Moo" => "1.003001";
requires "Plack" => "1.0018";
requires "Regexp::Common" => "2010010201";
requires "TryCatch" => "1.003000";
requires "URI" => "1.60";
requires "Web::Simple" => "0.020";
requires "local::lib" => "1.008004";
requires "namespace::sweep" => "0.006";
requires "parent" => "0.224";
requires "perl" => "5.010001";

on 'build' => sub {
  requires "Module::Build" => "0.4004";
  requires "Test::Requires" => "0.06";
  requires "version" => "0.88";
};

on 'configure' => sub {
  requires "Module::Build" => "0.4004";
  requires "version" => "0.88";
};
