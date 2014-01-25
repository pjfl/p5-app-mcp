package App::MCP::View::HTML;

use namespace::sweep;

use Moo;
use CGI::Simple::Cookie;
use Class::Usul::Constants;
use Class::Usul::Functions qw( base64_encode_ns throw );
use Encode;
use File::DataClass::Types qw( Directory Object );
use HTTP::Status           qw( HTTP_INTERNAL_SERVER_ERROR );
use Scalar::Util           qw( weaken );
use Storable               qw( nfreeze );
use Template;

extends q(App::MCP);

# Public attributes
has 'template_dir' => is => 'lazy', isa => Directory,
   builder         => sub { $_[ 0 ]->config->root->catdir( 'templates' ) },
   coerce          => Directory->coercion;

# Private attributes
has '_template' => is => 'lazy', isa => Object, builder => sub {
   my $self     =  shift;
   my $args     =  { RELATIVE     => TRUE,
                     INCLUDE_PATH => [ $self->template_dir->pathname ],
                     WRAPPER      => 'wrapper.tt', };
   my $template =  Template->new( $args )
      or throw error => $Template::ERROR, rv => HTTP_INTERNAL_SERVER_ERROR;

   return $template;
};

# Public methods
sub render {
   my ($self, $req, $stash) = @_; weaken( $req );

   my $html     = NUL;
   my $prefs    =  $stash->{prefs   } //  {};
   my $conf     =  $stash->{config  }   = $self->config;
   my $template = ($stash->{template} //= $conf->template).'.tt';
   my $cookie   = $self->_serialize_preferences( $req, $prefs );
   my $header   = __header( 'Set-Cookie', $cookie );

   $stash->{req    } = $req;
   $stash->{loc    } = sub { $req->loc( @_ ) };
   $stash->{uri_for} = sub { $req->uri_for( @_ ) };

   $self->_template->process( $template, $stash, \$html ) or
      throw error => $self->_template->error, rv => HTTP_INTERNAL_SERVER_ERROR;

   return [ $stash->{code}, $header, [ encode( 'UTF-8', $html ) ] ];
}

# Private methods
sub _serialize_preferences {
   my ($self, $req, $prefs) = @_; my $value = base64_encode_ns nfreeze $prefs;

   return CGI::Simple::Cookie->new( -domain  => $req->domain,
                                    -expires => '+3M',
                                    -name    => $self->config->name.'_prefs',
                                    -path    => $req->path,
                                    -value   => $value, );
}

# Private functions
sub __header {
   my @headers = ('Content-Type', 'text/html'); $_[ 0 ] and push @headers, @_;

   return [ @headers ];
}

1;

__END__

=pod

=encoding utf8

=head1 Name

App::MCP::View::HTML - One-line description of the modules purpose

=head1 Synopsis

   use App::MCP::View::HTML;
   # Brief but working code examples

=head1 Description

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=back

=head1 Subroutines/Methods

=head1 Diagnostics

=head1 Dependencies

=over 3

=item L<Class::Usul>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module. Please report problems to
http://rt.cpan.org/NoAuth/Bugs.html?Dist=App-MCP.
Patches are welcome

=head1 Acknowledgements

Larry Wall - For the Perl programming language

=head1 Author

Peter Flanigan, C<< <pjfl@cpan.org> >>

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
