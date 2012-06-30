package Inline::C::ParsePegex;
use strict;
use Carp;
use Pegex::Grammar;
use Pegex::Compiler;

use XXX;
use IO::All;
use YAML::XS;

sub register {
    {
     extends => [qw(C)],
     overrides => [qw(get_parser)],
    }
}

sub get_parser {
    Inline::C::_parser_test("Inline::C::ParsePegex::get_parser called\n") if $_[0]->{CONFIG}{_TESTING};
    bless {}, 'Inline::C::ParsePegex'
}

sub code {
    my($self,$code) = @_;

    $self->{data} = Load io('expect')->all;

    #XXX pegex($self->grammar)->parse($code);

    my $pegex_grammar = Pegex::Grammar->new(
        tree => Pegex::Compiler->compile($self->grammar)->tree,
        receiver => 'Inline::C::ParsePegex::AST',
    );
#    $Pegex::Parser::Debug = 1;

    $main::data = $pegex_grammar->parse($code);

   return 1;  # We never fail.
}

sub grammar {
    <<'...';

code:   <part>+

part:   <comment>
      | <function_definition>
      | <function_declaration>
      | <anything_else>

comment:
        /~<SLASH><SLASH>[^<BREAK>]*<BREAK>/
  | /~<SLASH><STAR>(?:[^<STAR>]+|<STAR>(?!<SLASH>))*<STAR><SLASH>([<TAB>]*)?/

function_definition:
        <rtype> /(<identifier>)/ <LPAREN> <arg>* % <COMMA> /~<RPAREN>~<LCURLY>~/

function_declaration:
        <rtype> /(<identifier>)/ <LPAREN> [ <arg_decl>* % <COMMA> ] /~<RPAREN>~<SEMI>~/

rtype: /<WS>*(?:<rtype1>|<rtype2>)<WS>*/

rtype1: /<modifier>*(<type_identifier>)<WS>*(<STAR>*)/

rtype2: /<modifier>+<STAR>*/

arg: /(?:<type><WS>*(<identifier>)|(<DOT><DOT><DOT>))/

arg_decl: /(<type><WS>*<identifier>*|<DOT><DOT><DOT>)/

type: /<WS>*(?:<type1>|<type2>)<WS>*/

type1: /<modifier>*(<type_identifier>)<WS>*(<STAR>*)/

type2: /<modifier>*<STAR>*/

modifier: /(?:(?:unsigned|long|extern|const)\b<WS>*)/

identifier: /(?:<WORD>+)/

type_identifier: /(?:<WORD>+)/

anything_else: /<ANY>*<EOL>/

...
}

package Inline::C::ParsePegex::AST;

use XXX;
use parent 'Pegex::Receiver';

sub initialize {
    my ($self) = @_;
    my $data = {
        AUTOWRAP => 0,
        done => {},
        function => {},
        functions => [],
    };
    $self->data($data);
}

sub got_code {
    my ($self) = @_;
    $self->data;
}

sub got_function_definition {
    my ($self, $ast) = @_;
    my ($rtype, $name, $args) = @$ast;
    my ($tname, $stars) = @$rtype;
    my $data = $self->data;
    my $def = $data->{function}{$name} = {};
    $def->{arg_names} = [];
    $def->{arg_types} = [];
    $def->{return_type} = $tname . ($stars ? " $stars" : '');
    for my $arg (@$args) {
        my ($type, $stars, $name) = @$arg;
        push @{$def->{arg_names}}, $name;
        push @{$def->{arg_types}}, $type . ($stars ? " $stars" : '');

    }
    push @{$data->{functions}}, $name;
    $data->{done}{$name} = 1;
    return;
}


sub got_arg {
    my ($self, $ast) = @_;
    pop @$ast;
    return $ast;
}

1;

__DATA__

=head1 NAME

Inline::C::ParsePegex - The New and Improved Inline::C Parser

=head1 SYNOPSIS

    use Inline C => DATA =>
               USING => ParsePegex;

=head1 DESCRIPTION

This module is a much faster version of Inline::C's Parse::RecDescent
parser. It is based on regular expressions instead.

=head2 AUTHOR

Mitchell N Charity <mcharity@vendian.org>

=head1 COPYRIGHT

Copyright (c) 2002. Brian Ingerson.

Copyright (c) 2008, 2010-2012. Sisyphus.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut
