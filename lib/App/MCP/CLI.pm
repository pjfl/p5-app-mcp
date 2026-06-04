package App::MCP::CLI;

use App::MCP::Constants    qw( EXCEPTION_CLASS FAILED FALSE NUL OK TRUE );
use File::DataClass::Types qw( ArrayRef Directory Str );
use App::MCP::Util         qw( local_config trigger_event_handler );
use Class::Usul::Cmd::Util qw( decrypt elapsed ensure_class_loaded );
use English                qw( -no_match_vars );
use File::DataClass::IO    qw( io );
use HTML::Forms::Util      qw( json_bool );
use Type::Utils            qw( class_type );
use Unexpected::Functions  qw( throw Timedout UnknownToken UnknownUser
                               Unspecified );
use App::MCP::Markdown;
use Moo;
use Class::Usul::Cmd::Options;

extends 'Class::Usul::Cmd';
with    'App::MCP::Role::Config';
with    'App::MCP::Role::Log';
with    'App::MCP::Role::JSONParser';
with    'App::MCP::Role::Redis';
with    'App::MCP::Role::Schema';
with    'App::MCP::Role::Webpush';
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

=item C<assetdir>

Subdirectory of the document root containing image files

=cut

has 'assetdir' =>
   is      => 'lazy',
   isa     => Directory,
   default => sub { shift->config->rootdir->catdir('img') };

=item C<formatter>

An instance of the L<markdown formatter|App::MCP::Markdown>

=cut

has 'formatter' =>
   is      => 'lazy',
   isa     => class_type('App::MCP::Markdown'),
   default => sub { App::MCP::Markdown->new( tab_width => 3 ) };

=item C<projects>

A list of projects which contain the JS and LESS files used in this
application. Local copies of these files are made before processing and
saving under the document root

=cut

has 'projects' =>
   is      => 'ro',
   isa     => ArrayRef,
   default => sub {
      return [qw(HTML-Filter HTML-Forms HTML-StateTable Web-Components)];
   };

=item C<templatedir>

Directory containing email templates in Markdown format

=cut

has 'templatedir' =>
   is      => 'lazy',
   isa     => Directory,
   default => sub {
      my $self   = shift;
      my $vardir = $self->config->vardir;

      return $vardir->catdir('templates', $self->config->skin, 'site');
   };

=item C<user_name>

Defaults from configuration to the application prefix C<mcp>. Can set from
the command line with either C<--user-name> or C<-u>

=cut

option 'user_name' =>
   is            => 'lazy',
   isa           => Str,
   documentation => 'Name in the user table',
   default       => sub { shift->config->prefix },
   format        => 's',
   short         => 'u';

=item C<user_password>

This should be in the local configuration file. See
L<store password|App::MCP::Schema>

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

=back

=head1 Subroutines/Methods

Defines the following methods;

=over 3

=item C<BUILD>

Does nothing

=cut

sub BUILD {}

=item C<install> - Creates directories and starts schema installation

Creates directories and starts schema installation. Needs to run before
the schema admin program creates the database so that the config object
sees the right directories

=cut

sub install : method {
   my $self   = shift;
   my $config = $self->config;

   for my $dir (qw(backup log root run share sql tmp)) {
      my $path = $config->vardir->catdir($dir);

      $path->mkpath(oct '0770') unless $path->exists;
   }

   for my $dir (qw(css fonts img js sounds)) {
      my $path = $config->rootdir->catdir($dir);

      $path->mkpath(oct '0770') unless $path->exists;
   }

   $self->_create_profile;

   my $prefix = $config->prefix;
   my $cmd    = $config->bin->catfile("${prefix}-schema");

   $self->_install_schema($cmd) if $cmd->exists;

   return OK;
}

=item C<make_all> - Run JS and CSS production methods

A convienience method which calls the other three front end file production
methods

=cut

sub make_all : method {
   my $self = shift;

   $self->make_css;
   $self->make_js;
   return OK;
}

=item C<make_css> - Make concatenated CSS file

Run automatically if L<App::Burp> is running. It calls C<make-less> and then
concatenates multiple CSS files into a single one

=cut

sub make_css : method {
   my $self  = shift;
   my $dir   = io['share', 'css'];
   my @files = ();

   $self->make_less;
   $dir->filter(sub { m{ \.css \z }mx })->visit(sub { push @files, shift });

   my $skin   = $self->config->skin;
   my $prefix = $self->config->prefix;
   my $file   = "${prefix}-${skin}.css";
   my $out    = io([qw(var root css), $file])->assert_open('a')->truncate(0);
   my $count  =()= map  { $out->append($_->slurp) }
                   sort { $a->name cmp $b->name } @files;
   my $context = { leader => 'CLI.make_css' };

   $self->info("Concatenated ${count} files to ${file}", $context);
   return OK;
}

=item C<make_js> - Make concatenated JS file

Run automatically if L<App::Burp> is running. It concatenates multiple JS files
into a single one. Strips JSDoc comments

=cut

sub make_js : method {
   my $self  = shift;
   my $dir   = io['share', 'js'];
   my @files = ();

   $self->_populate_share_files($dir, 'js');
   $dir->filter(sub { m{ \.js \z }mx })->visit(sub { push @files, shift });

   my $prefix = $self->config->prefix;
   my $file   = "${prefix}.js";
   my $out    = io([qw(var root js), $file])->assert_open('a')->truncate(0);
   my $count  =()= map  { $out->appendln($self->_strip_comments($_->slurp)) }
                   sort { $a->name cmp $b->name } @files;
   my $context = { leader => 'CLI.make_js' };

   $self->info("Concatenated ${count} files to ${file}", $context);
   return OK;
}

=item C<make_less> - Convert LESS files to CSS

Run automatically if L<App::Burp> is running. Compiles LESS files down to CSS
files

=cut

sub make_less : method {
   my $self  = shift;
   my $dir   = io['share', 'less'];
   my @files = ();

   $self->_populate_share_files($dir, 'less');
   $dir->filter(sub { m{ \.less \z }mx })->visit(sub { push @files, shift });
   ensure_class_loaded('CSS::LESS');

   my $prefix = $self->config->prefix;
   my $file   = "${prefix}.css";
   my $out    = io([qw(share css), $file])->assert_open('a')->truncate(0);
   my $lessc  = CSS::LESS->new(include_paths => ["${dir}"]);
   my $count  =()= map  { $out->append($lessc->compile($_->all)) }
                   sort { $a->name cmp $b->name } @files;
   my $context = { leader => 'CLI.make_less' };

   $self->info("Concatenated ${count} files to ${file}", $context);
   return OK;
}

=item C<send_event> - Create a job state transition event

The default event transition is C<start>

=cut

sub send_event : method {
   my $self     = shift;
   my $job_name = $self->next_argv or throw Unspecified, ['job name'];
   my $trans    = $self->next_argv // 'start';
   my $delay    = $self->options->{delay};

   if ($delay) {
      my $code = sub { sleep $delay; $self->_send_event($job_name, $trans) };

      $self->run_cmd([$code], { detach => TRUE });
      sleep 3;
   }
   else { $self->_send_event($job_name, $trans) }

   return OK;
}

=item C<send_message> - Send an email or SMS message

Send either email or SMS messages to a list of recipients. The SMS client is
unimplemented

=cut

sub send_message : method {
   my $self   = shift;
   my $sink   = $self->next_argv or throw Unspecified, ['message sink'];
   my $method = "_send_${sink}";

   throw 'Message sink [_1] unknown', [$sink] unless $self->can($method);

   return $self->$method() ? OK : FAILED;
}

# Private methods
sub _authenticate_user {
   my $self     = shift;
   my $username = $self->user_name;
   my $user_rs  = $self->schema->resultset('User');
   my $user     = $user_rs->authenticate($username, $self->user_password);

   $self->log->debug("CLI.authenticate_user: User ${username} authenticated");

   return { user => $user, groups => $user->groups };
}

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
   my $self     = shift;
   my $options  = $self->options;
   my $quote    = $self->next_argv ? TRUE : $options->{quote} ? TRUE : FALSE;
   my $token    = $options->{token} or throw Unspecified, ['token'];
   my $encoded  = $self->redis_client->get("send_message-${token}")
      or throw UnknownToken, [$token];
   my $stash    = $self->json_parser->decode($encoded);
   my $template = delete $stash->{template};
   my $path     = $self->templatedir->catdir('email')->catfile($template);

   $path = io $template unless $path->exists;

   $stash->{content} = $path->all;
   $stash->{content} = $self->formatter->markdown($stash->{content})
      if $template =~ m{ \.md \z }mx;

   my $tempdir = $self->config->tempdir;

   unlink $template if $tempdir eq substr $template, 0, length $tempdir;

   $stash->{quote} = $quote;
   $stash->{token} = $token;
   return $stash;
}

sub _populate_share_files {
   my ($self, $dest, $extn) = @_;

   my $filter = sub { m{ \.${extn} \z }mx };
   my @files  = ();
   my $mtimes = {};

   $dest->filter($filter)->visit(sub { push @files, shift});

   $mtimes->{$_->basename} = $_->stat->{mtime} for (@files);

   for my $source ($self->_qualified_share_files($extn)) {
      next if exists $mtimes->{$source->basename}
         && $mtimes->{$source->basename} >= $source->stat->{mtime};

      $source->copy($dest);
   }

   return;
}

sub _qualified_share_files {
   my ($self, $extn) = @_;

   my $proj_parent = $self->config->appldir->parent->parent;
   my $filter      = sub { m{ \.${extn} \z }mx };
   my @files       = ();

   for my $project (@{$self->projects}) {
      my $proj_dir = $proj_parent->catdir($project);

      next unless $proj_dir->exists;

      my $source = $proj_dir->catdir(qw(master share), $extn);

      next unless $source->exists;

      $source->filter($filter)->visit(sub { push @files, shift });
   }

   return @files;
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
   my $self       = shift;
   my $stash      = $self->_load_stash;
   my $attaches   = $self->_qualify_assets(delete $stash->{attachments});
   my $user_rs    = $self->schema->resultset('User');
   my $recipients = delete $stash->{recipients};
   my $context    = { leader => 'CLI.send_message' };
   my $success    = TRUE;

   for my $recipient (@{$recipients // []}) {
      if ($recipient =~ m{ \A \d+ \z }mx) {
         my $user = $user_rs->find_by_key($recipient);

         unless ($user) {
            $self->error("User ${recipient} unknown", $context);
            next;
         }

         unless ($user->can_email) {
            $self->error("User ${user} bad email address", $context);
            next;
         }

         $stash->{email} = $user->email;
         $stash->{username} = "${user}";
      }
      else { $stash->{email} = $recipient }

      $success = FALSE unless $self->_send_email_single($stash, $attaches);
   }

   return $success;
}

sub _send_email_single {
   my ($self, $stash, $attaches) = @_;

   my $encoding = $self->config->encoding;
   my $attr     = { charset => $encoding, content_type => 'text/html' };
   my $content  = $stash->{content};
   my $wrapper  = $self->config->skin . '/site/wrapper/email.tt';
   my $template = "[% WRAPPER '${wrapper}' %]${content}[% END %]";
   my $post     = {
      attributes => $attr,
      from       => $self->config->name,
      stash      => $stash,
      subject    => $stash->{subject} // 'No subject',
      template   => \$template,
      to         => $stash->{email},
   };

   $post->{attachments} = $attaches if $attaches;

   my ($id) = $self->send_email($post);

   return FALSE unless $id;

   my $args    = [$stash->{email}, $id];
   my $context = { args => $args, leader => 'CLI.send_message' };

   $self->info('Emailed [_1] message id. [_2]', $context);

   return TRUE;
}

sub _send_event {
   my ($self, $job_name, $trans) = @_;

   my $job_rs    = $self->schema->resultset('Job');
   my $user      = $self->_authenticate_user->{user};
   my $job       = $job_rs->assert_executable($job_name, $user);
   my $params    = { job_id => $job->id, transition => $trans };
   my $event     = $self->schema->resultset('Event')->create($params);
   my $triggered = trigger_event_handler $self->config;
   my $id        = $event->id;
   my $message   = "Job ${job_name} transition ${trans} event id ${id}";

   if ($triggered) { $self->log->debug("CLI.send_event: ${message}") }
   else { $self->error("CLI.send_event: ${message} failed to signal daemon") }

   return;
}

sub _send_notification {
   my $self      = shift;
   my $options   = $self->options;
   my $recipient = $options->{recipient} or throw Unspecified, ['recipient'];
   my $user      = $self->schema->resultset('User')->find_by_key($recipient);

   throw UnknownUser, [$recipient] unless $user;

   my $beep    = json_bool $options->{beep};
   my $status  = $options->{status} // 'info';
   my $message = $options->{message} // 'No message';
   my $native  = json_bool $options->{native};
   my $title   = $options->{title} // 'MCP Service Worker';
   my $opts    = { status => $status, beep => $beep, title => $title };
   my $params  = { message => $message, native => $native, options => $opts };
   my $res     = $self->service_worker_push($user->id, $params);
   my $args    = ["${user}", $message];
   my $context = { args => $args, leader => 'CLI.send_message' };

   if ($res->{success}) {
      $self->info('Notified [_1] - [_2]', $context);
      return TRUE;
   }

   $self->error($res->{error}, $context);
   return FALSE;
}

sub _send_sms { ... }

sub _send_sms_single { ... }

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

=item L<App::MCP::Role::Webpush>

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
