package App::MCP::CLI;

use App::MCP::Constants    qw( EXCEPTION_CLASS FALSE NUL OK TRUE );
use File::DataClass::Types qw( Directory );
use Class::Usul::Cmd::Util qw( elapsed ensure_class_loaded );
use English                qw( -no_match_vars );
use File::DataClass::IO    qw( io );
use Type::Utils            qw( class_type );
use Unexpected::Functions  qw( throw Timedout UnknownToken Unspecified );
use App::MCP::Markdown;
use Moo;
use Class::Usul::Cmd::Options;

extends 'Class::Usul::Cmd';
with    'App::MCP::Role::Config';
with    'App::MCP::Role::Log';
with    'App::MCP::Role::Schema';
with    'App::MCP::Role::JSONParser';
with    'App::MCP::Role::Redis';
with    'Web::Components::Role::Email';

=pod

=encoding utf-8

=head1 Name

App::MCP::CLI - Command line interface to utility methods

=head1 Synopsis

   #!/usr/bin/env perl
   use App::MCP::CLI;

   exit App::MCP::CLI->new_with_options->run;

   # With the above in an excutable script
   mcp-cli -o token=<random_redis_key> send-message email

   mcp-cli list-methods

   mcp-cli help <method>

=head1 Description

Command line interface to utility methods

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=item C<redis_client_name>

=cut

has '+redis_client_name' => default => 'job_stash';

=item C<assetdir>

=cut

has 'assetdir' =>
   is      => 'lazy',
   isa     => Directory,
   default => sub { shift->config->rootdir->catdir('img') };

=item C<formatter>

=cut

has 'formatter' =>
   is      => 'lazy',
   isa     => class_type('App::MCP::Markdown'),
   default => sub { App::MCP::Markdown->new( tab_width => 3 ) };

=item C<templatedir>

=cut

has 'templatedir' =>
   is      => 'lazy',
   isa     => Directory,
   default => sub {
      my $self   = shift;
      my $vardir = $self->config->vardir;

      return $vardir->catdir('templates', $self->config->skin, 'site');
   };

=back

=head1 Subroutines/Methods

Defines the following methods;

=over 3

=cut

sub BUILD {}

=item install - Creates directories and starts schema installation

Creates directories and starts schema installation. Needs to run before
the schema admin program creates the database so that the config object
sees the right directories

=cut

sub install : method {
   my $self   = shift;
   my $config = $self->config;

   for my $dir (qw( backup log tmp )) {
      my $path = $config->vardir->catdir($dir);

      $path->mkpath(oct '0770') unless $path->exists;
   }

   # Share directory for bug attachments
   my $path = $config->rootdir->catdir('bugs');

   $path->mkpath(oct '0770') unless $path->exists;

   # Share directory for documentation
   $path = $config->rootdir->catdir('file');

   $path->mkpath(oct '0770') unless $path->exists;

   $self->_create_profile;

   my $prefix = $config->prefix;
   my $cmd    = $config->bin->catfile("${prefix}-schema");

   $self->_install_schema($cmd) if $cmd->exists;

   return OK;
}

=item make_css - Make concatenated CSS file

Run automatically if L<App::Burp> is running. It concatenates multiple CSS files
into a single one

=cut

sub make_css : method {
   my $self  = shift;
   my $dir   = io['share', 'css'];
   my @files = ();

   $dir->filter(sub { m{ \.css \z }mx })->visit(sub { push @files, shift });

   my $skin   = $self->config->skin;
   my $prefix = $self->config->prefix;
   my $file   = "${prefix}-${skin}.css";
   my $out    = io([qw( var root css ), $file])->assert_open('a')->truncate(0);
   my $count  =()= map  { $out->append($_->slurp) }
                   sort { $a->name cmp $b->name } @files;
   my $options = { name => 'CLI.make_css' };

   $self->info("Concatenated ${count} files to ${file}", $options);
   return OK;
}

=item make_js - Make concatenated JS file

Run automatically if L<App::Burp> is running. It concatenates multiple JS files
into a single one. Strips JSDoc comments

=cut

sub make_js : method {
   my $self  = shift;
   my $dir   = io['share', 'js'];
   my @files = ();

   $dir->filter(sub { m{ \.js \z }mx })->visit(sub { push @files, shift });

   my $prefix = $self->config->prefix;
   my $file   = "${prefix}.js";
   my $out    = io([qw( var root js ), $file])->assert_open('a')->truncate(0);
   my $count  =()= map  { $out->appendln($self->_strip_comments($_->slurp)) }
                   sort { $a->name cmp $b->name } @files;
   my $options = { name => 'CLI.make_js' };

   $self->info("Concatenated ${count} files to ${file}", $options);
   return OK;
}

=item make_less - Convert LESS files to CSS

Run automatically if L<App::Burp> is running. Compiles LESS files down to CSS
files

=cut

sub make_less : method {
   my $self  = shift;
   my $dir   = io['share', 'less'];
   my @files = ();

   $dir->filter(sub { m{ \.less \z }mx })->visit(sub { push @files, shift });
   ensure_class_loaded('CSS::LESS');

   my $prefix = $self->config->prefix;
   my $file   = "${prefix}.css";
   my $out    = io([qw( share css ), $file])->assert_open('a')->truncate(0);
   my $count  =()= map  { $out->append(CSS::LESS->new()->compile($_->all)) }
                   sort { $a->name cmp $b->name } @files;
   my $options = { name => 'CLI.make_less' };

   $self->info("Concatenated ${count} files to ${file}", $options);
   return OK;
}

=item send_message - Send an email or SMS message

Send either email or SMS messages to a list of recipients. The SMS client is
unimplemented

=cut

sub send_message : method {
   my $self     = shift;
   my $options  = $self->options;
   my $sink     = $self->next_argv or throw Unspecified, ['message sink'];
   my $quote    = $self->next_argv ? TRUE : $options->{quote} ? TRUE : FALSE;
   my $stash    = $self->_load_stash($quote);
   my $attaches = $self->_qualify_assets(delete $stash->{attachments});
   my $log_opts = { name => 'CLI.send_message' };

   if ($sink eq 'email') {
      my $recipients = delete $stash->{recipients};
      my $rs = $self->schema->resultset('User');

      for my $id_or_email (@{$recipients // []}) {
         if ($id_or_email =~ m{ @ }mx) { $stash->{email} = $id_or_email }
         else {
            my $user = $rs->find_by_key($id_or_email);

            unless ($user) {
               $self->error("User ${id_or_email} unknown", $log_opts);
               next;
            }

            unless ($user->can_email) {
               $self->error("User ${user} bad email address", $log_opts);
               next;
            }

            $stash->{email} = $user->email;
            $stash->{username} = "${user}";
         }

         $self->_send_email($stash, $attaches);
      }
   }
   elsif ($sink eq 'sms') { $self->_send_sms($stash) }
   else { throw 'Message sink [_1] unknown', [$sink] }

   return OK;
}

=item wait_for_file - Waits for the file specified by option 'path'

Polling frequency defaults to once every five seconds and is set by the option
'rate'. If option 'timeout' is set and the elapsed runtime exceeds this,
exit with a non zero return code (fail)

=cut

sub wait_for_file : method {
   my $self = shift;

   throw Unspecified, ['option path'] unless exists $self->options->{path};

   my $path = io $self->options->{path};

   $path = $path->absolute($self->config->vardir) unless $path->is_absolute;

   my $rate    = $self->options->{rate} // 5;
   my $timeout = $self->options->{timeout} // 0;

   while (!$path->exists) {
      throw Timedout, [$timeout, $path] if $timeout and elapsed > $timeout;

      sleep $rate;
   }

   return OK;
}

# Private methods
sub _create_profile {
   my $self = shift;

   $self->output('Env var PERL5LIB is '.$ENV{PERL5LIB});
   $self->yorn('+Is this correct', FALSE, TRUE, 0) or return;
   $self->output('Env var PERL_LOCAL_LIB_ROOT is '.$ENV{PERL_LOCAL_LIB_ROOT});
   $self->yorn('+Is this correct', FALSE, TRUE, 0) or return;

   my $localdir = $self->config->home->catdir('local');
   my $prefix   = $self->config->prefix;
   my $filename = "${prefix}-profile";
   my $profile;

   if ($localdir->exists) {
      $profile = $localdir->catfile('var', 'etc', $filename);
   }
   elsif ($localdir = io['~', 'local'] and $localdir->exists) {
      $profile = $self->config->vardir->catfile('etc', $filename);
   }
   elsif ($localdir = io($ENV{PERL_LOCAL_LIB_ROOT} // NUL)
          and $localdir->exists) {
      $profile = $self->config->vardir->catfile('etc', $filename);
   }

   return if !$profile || $profile->exists;

   my $inc     = $localdir->catdir('lib', 'perl5');
   my $cmd     = [$EXECUTABLE_NAME, '-I', "${inc}", "-Mlocal::lib=${localdir}"];
   my $p5lib   = delete $ENV{PERL5LIB};
   my $libroot = delete $ENV{PERL_LOCAL_LIB_ROOT};

   $self->run_cmd($cmd, { err => 'stderr', out => $profile });
   $ENV{PERL5LIB} = $p5lib;
   $ENV{PERL_LOCAL_LIB_ROOT} = $libroot;
   return;
}

sub _install_schema {
   my ($self, $cmd) = @_;

   my $opts = { err => 'stderr', in => 'stdin', out => 'stdout' };

   $self->run_cmd([$cmd, '-o', 'bootstrap=1', 'install'], $opts);
   return;
}

sub _load_stash {
   my ($self, $quote) = @_;

   my $token    = $self->options->{token} or throw Unspecified, ['token'];
   my $encoded  = $self->redis_client->get($token)
      or throw UnknownToken, [$token];
   my $stash    = $self->json_parser->decode($encoded);
   my $template = delete $stash->{template};
   my $path     = $self->templatedir->catdir('email')->catfile($template);

   $path = io $template unless $path->exists;

   $stash->{content} = $path->all;
   $stash->{content} = $self->formatter->markdown($stash->{content})
      if $template =~ m{ \.md \z }mx;

   my $tempdir  = $self->config->tempdir;

   unlink $template if $tempdir eq substr $template, 0, length $tempdir;

   $stash->{quote} = $quote;
   return $stash;
}

sub _qualify_assets {
   my ($self, $files) = @_;

   return FALSE unless $files;

   my $assets = {};

   for my $file (@{$files}) {
      my $path = $self->assetdir->catfile($file);

      $path = io $file unless $path->exists;

      next unless $path->exists;

      $assets->{$path->basename} = $path;
   }

   return $assets;
}

sub _send_email {
   my ($self, $stash, $attaches) = @_;

   my $content  = $stash->{content};
   my $wrapper  = $self->config->skin . '/site/wrapper/email.tt';
   my $template = "[% WRAPPER '${wrapper}' %]${content}[% END %]";
   my $post     = {
      attributes      => {
         charset      => $self->config->encoding,
         content_type => 'text/html',
      },
      from            => $self->config->name,
      stash           => $stash,
      subject         => $stash->{subject} // 'No subject',
      template        => \$template,
      to              => $stash->{email},
   };

   $post->{attachments} = $attaches if $attaches;

   my ($id)    = $self->send_email($post);
   my $options = { args => [$stash->{email}, $id], name => 'CLI.send_message' };

   $self->info('Emailed [_1] message id. [_2]', $options);
   return;
}

sub _send_sms { ... }

sub _strip_comments {
   my ($self, @js) = @_;

   my $js = join NUL, @js;

   $js =~ s{ /\*\* [^*]* \*/ }{}gmsx;
   $js =~ s{ \n [ ]* \n }{\n}gmsx;

   return split m{ \n }mx, $js, -1;
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

=item L<File::DataClass>

=item L<Moo>

=item L<Text::MultiMarkdown>

=item L<Web::Components::Role::Email>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module.  Please report problems to the address
below.  Patches are welcome

=head1 Acknowledgements

Larry Wall - For the Perl programming language

=head1 Author

Peter Flanigan, C<< <pjfl@cpan.org> >>

=head1 License and Copyright

Copyright (c) 2024 Peter Flanigan. All rights reserved

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
