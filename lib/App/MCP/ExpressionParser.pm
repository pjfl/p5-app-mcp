# @(#)$Id$

package App::MCP::ExpressionParser;

use strict;
use warnings;
use feature qw(state);
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev$ =~ /\d+/gmx );

use Class::Usul::Functions qw(arg_list throw);
use Marpa::R2;

sub new {
   my ($self, @args) = @_; my $attr = arg_list @args;

   return bless {
      debug    => $attr->{debug},
      external => $attr->{external},
      tokens   => __tokens( $attr->{predicates} ), }, ref $self || $self;
}

sub parse {
   my ($self, $line, $ns) = @_; my $identifiers = {}; my $last = 0;

   my $line_length = length $line; my $pos = 0; my $recog = $self->_recogniser;

   while ($pos < $line_length) {
      my $expected_tokens = $recog->terminals_expected;

      scalar @{ $expected_tokens } or next;

      for my $token ($self->_lex( \$line, $pos, $expected_tokens )) {
         $pos += $token->[ 2 ]; $token->[ 0 ] eq 'SP' and next;

         if ($token->[ 0 ] eq 'IDENTIFIER') {
            my $name = $token->[ 1 ];
            my $fqjn = $ns && $name !~ m{ :: }msx ? "${ns}::${name}" : $name;

            $identifiers->{ $token->[ 1 ] = $fqjn } = 1;
         }

         $recog->read( @{ $token } );
      }

      $pos == $last
         and throw error => 'Expression [_1] parse error - char [_2]',
                   args  => [ $line, $pos ];
      $last = $pos;
   }

   $recog->end_input; my $expr_value_ref = $recog->value;

   $expr_value_ref or throw error => 'Expression [_1] has no value',
                            args  => [ $line ];

   return [ ${ $expr_value_ref }, [ keys %{ $identifiers } ] ];
}

# Private methods

sub _grammar {
   my $self = shift; state $cache; $cache and return $cache;

   my $grammar = Marpa::R2::Grammar->new( {
      action_object   => 'external',
      actions         => 'App::MCP::ExpressionParser::Actions',
      start           => 'expression',
      rules           => [
         [ expression => [ qw(expression OPERATOR expression) ] => 'operate'  ],
         [ expression => [ qw(LP expression RP)               ] => 'subrule2' ],
         [ expression => [ qw(NOT expression)                 ] => 'negate'   ],
         [ expression => [ qw(call)                           ] => 'subrule1' ],
         [ call       => [ qw(function LP job_name RP)        ] => 'callfunc' ],
         [ function   => [ 'PREDICATE'                        ] => 'subrule1' ],
         [ job_name   => [ 'IDENTIFIER'                       ] => 'subrule1' ],
         ],
      } );

   $grammar->precompute;

   return $cache = $grammar;
}

sub _lex {
   my ($self, $input, $pos, $expected) = @_; my @matches;

   for my $token_name ('SP', @{ $expected }) {
      my $token = $self->{tokens}->{ $token_name }
         or throw error => 'Token [_1] unknown', args => [ $token_name ];
      my $rule  = $token->[ 0 ];

      pos( ${ $input } ) = $pos; ${ $input } =~ $rule or next;

      my $matched_len = $+[ 0 ] - $-[ 0 ]; my $matched_value = undef;

      if (defined( my $val = $token->[ 1 ] )) {
         if (ref $val eq 'CODE') { $matched_value = $val->() }
         else { $matched_value = $val }
      }
      elsif ($#- > 0) { # Captured a value
         $matched_value = $1;
      }

      push @matches, [ $token_name, $matched_value, $matched_len ];
   }

   return @matches;
}

sub _recogniser {
   my $self = shift;
   my $attr = {
      closures       => { 'external::new' => sub { $self->{external} } },
      grammar        => $self->_grammar,
      ranking_method => 'rule',
   };

   if ($self->{debug}) {
      $attr->{trace_terminals} = 2;
      $attr->{trace_values   } = 1;
      $attr->{trace_actions  } = 1;
   }

   return Marpa::R2::Recognizer->new( $attr );
}

# Private functions

sub __tokens {
   my $predicates = shift; $predicates = join '|', @{ $predicates };

   return {
      'LP'         => [ qr{ \G [\(]                }msx      ],
      'RP'         => [ qr{ \G [\)]                }msx      ],
      'SP'         => [ qr{ \G [ ]                 }msx, ' ' ],
      'NOT'        => [ qr{ \G [\!]                }msx      ],
      'OPERATOR'   => [ qr{ \G (\&|\|)             }msx      ],
      'PREDICATE'  => [ qr{ \G ($predicates)       }msx      ],
      'IDENTIFIER' => [ qr{ \G ([a-zA-Z0-9_\-+:]+) }msx      ],
   };
}

package # Hide from indexer
   App::MCP::ExpressionParser::Actions;

sub callfunc {
   my $func = $_[ 1 ]; return $_[ 0 ]->$func( $_[ 3 ] );
}

sub negate {
   return $_[ 2 ] ? 0 : 1;
}

sub operate {
   return $_[ 2 ] eq '&' ? $_[ 1 ] && $_[ 3 ] : $_[ 1 ] || $_[ 3 ];
}

sub subrule1 {
   return $_[ 1 ];
}

sub subrule2 {
   return $_[ 2 ];
}

1;

__END__

=pod

=head1 Name

App::MCP::ExpressionParser - <One-line description of module's purpose>

=head1 Version

0.1.$Revision$

=head1 Synopsis

   use App::MCP::ExpressionParser;
   # Brief but working code examples

=head1 Description

=head1 Configuration and Environment

=head1 Subroutines/Methods

=head2 new

=head2 parse

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

Copyright (c) 2012 Peter Flanigan. All rights reserved

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
