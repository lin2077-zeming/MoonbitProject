// Copyright (c) 2024 LinZeming
// Released under the MIT License
//
// Black-box tests for the lexer.

/// Shortcut: tokenize and unwrap the result.
fn tok(input : String) -> Array[@tpl.Token] {
  match @tpl.lexer.tokenize(input) {
    Ok(tokens) => tokens
    Err(msg) => {
      @prelude.fail("tokenize failed: " + msg)
    }
  }
}

/// Extract token kinds from a token array (drop Eof for comparison convenience).
fn kinds(tokens : Array[@tpl.Token]) -> Array[@tpl.TokenKind] {
  let arr : Array[@tpl.TokenKind] = Array::new()
  for tok in tokens {
    if tok.kind != @tpl.TokenKind::Eof {
      arr.push(tok.kind)
    }
  }
  arr
}

/// Helper: get the first (non-Eof) token kind.
fn first_kind(input : String) -> @tpl.TokenKind {
  let tokens = tok(input)
  tokens[0].kind
}

/// Helper: get the nth token kind (0-indexed).
fn nth_kind(input : String, n : Int) -> @tpl.TokenKind {
  let tokens = tok(input)
  tokens[n].kind
}

// =============================================================================
// 1. Plain text tokenization
// =============================================================================

test "plain text" {
  let tokens = tok("Hello, World!")
  let ks = kinds(tokens)
  inspect!(ks, content="[Text(Hello, World!)]")
}

test "empty input" {
  let tokens = tok("")
  // Should only contain Eof
  @prelude.assert_eq!(tokens.length(), 1)
  @prelude.assert_eq!(tokens[0].kind, @tpl.TokenKind::Eof)
}

test "text with newlines" {
  let tokens = tok("line1\nline2\n")
  let ks = kinds(tokens)
  inspect!(ks, content="[Text(line1\nline2\n)]")
}

test "text with lone braces" {
  let tokens = tok("a { b } c")
  let ks = kinds(tokens)
  // Lone { and } are just text, not tags
  inspect!(ks, content="[Text(a { b } c)]")
}

// =============================================================================
// 2. Simple variable interpolation
// =============================================================================

test "simple variable {{ name }}" {
  let tokens = tok("{{ name }}")
  let ks = kinds(tokens)
  inspect!(ks, content="[OpenVar, Ident(name), CloseVar]")
}

test "variable with preceding text" {
  let tokens = tok("Hello, {{ name }}!")
  let ks = kinds(tokens)
  inspect!(ks, content="[Text(Hello, ), Ident(name), CloseVar, Text(!)]")
}

test "variable with dot access" {
  let tokens = tok("{{ user.name }}")
  let ks = kinds(tokens)
  inspect!(ks, content="[OpenVar, Ident(user), Dot, Ident(name), CloseVar]")
}

test "variable with index access" {
  let tokens = tok("{{ items[0] }}")
  let ks = kinds(tokens)
  inspect!(ks, content="[OpenVar, Ident(items), LBracket, Int(0), RBracket, CloseVar]")
}

test "multiple variables" {
  let tokens = tok("{{ a }}{{ b }}")
  let ks = kinds(tokens)
  inspect!(ks, content="[OpenVar, Ident(a), CloseVar, OpenVar, Ident(b), CloseVar]")
}

// =============================================================================
// 3. Variables with filters
// =============================================================================

test "variable with upper filter" {
  let tokens = tok("{{ name | upper }}")
  let ks = kinds(tokens)
  inspect!(ks, content="[OpenVar, Ident(name), Pipe, Ident(upper), CloseVar]")
}

test "variable with chained filters" {
  let tokens = tok("{{ name | upper | trim }}")
  let ks = kinds(tokens)
  inspect!(ks, content="[OpenVar, Ident(name), Pipe, Ident(upper), Pipe, Ident(trim), CloseVar]")
}

test "variable with filter and args" {
  let tokens = tok("{{ name | default('N/A') }}")
  let ks = kinds(tokens)
  inspect!(ks, content="[OpenVar, Ident(name), Pipe, Ident(default), LParen, Str(N/A), RParen, CloseVar]")
}

// =============================================================================
// 4. If tags
// =============================================================================

test "if block" {
  let tokens = tok("{% if x %}yes{% endif %}")
  let ks = kinds(tokens)
  inspect!(ks, content="[OpenTag, If, Ident(x), CloseTag, Text(yes), OpenTag, Endif, CloseTag]")
}

test "if elif else block" {
  let tokens = tok("{% if a %}A{% elif b %}B{% else %}C{% endif %}")
  let ks = kinds(tokens)
  inspect!(ks, content="[OpenTag, If, Ident(a), CloseTag, Text(A), OpenTag, Elif, Ident(b), CloseTag, Text(B), OpenTag, Else, CloseTag, Text(C), OpenTag, Endif, CloseTag]")
}

test "if with and/or/not" {
  let tokens = tok("{% if a and not b %}x{% endif %}")
  let ks = kinds(tokens)
  inspect!(ks, content="[OpenTag, If, Ident(a), And, Not, Ident(b), CloseTag, Text(x), OpenTag, Endif, CloseTag]")
}

// =============================================================================
// 5. For loop tags
// =============================================================================

test "for loop" {
  let tokens = tok("{% for x in items %}{{ x }}{% endfor %}")
  let ks = kinds(tokens)
  inspect!(ks, content="[OpenTag, For, Ident(x), In, Ident(items), CloseTag, OpenVar, Ident(x), CloseVar, OpenTag, Endfor, CloseTag]")
}

test "for loop with key value" {
  let tokens = tok("{% for k, v in map %}{{ k }}:{{ v }}{% endfor %}")
  let ks = kinds(tokens)
  inspect!(ks, content="[OpenTag, For, Ident(k), Comma, Ident(v), In, Ident(map), CloseTag, OpenVar, Ident(k), CloseVar, Text(:), OpenVar, Ident(v), CloseVar, OpenTag, Endfor, CloseTag]")
}

// =============================================================================
// 6. Comments are skipped
// =============================================================================

test "comments are skipped" {
  let tokens = tok("before{# this is a comment #}after")
  let ks = kinds(tokens)
  inspect!(ks, content="[Text(before), Text(after)]")
}

test "comment at start" {
  let tokens = tok("{# comment #}Hello")
  let ks = kinds(tokens)
  inspect!(ks, content="[Text(Hello)]")
}

test "comment only" {
  let tokens = tok("{# just a comment #}")
  let ks = kinds(tokens)
  // Only Eof, no content tokens
  @prelude.assert_eq!(kinds(tokens).length(), 0)
}

test "comment inside expression is not skipped" {
  // {# inside {{ }} is not a comment — it's part of the expression
  let tokens = tok("{{ {# is not comment #} }}")
  let ks = kinds(tokens)
  // {# inside expression should be treated as operators + text
  inspect!(ks, content="[OpenVar, LBracket, Error(..), Ident(is), Ident(not), Ident(comment), Error(..), RBracket, CloseVar]")
}

// =============================================================================
// 7. String literals
// =============================================================================

test "double quoted string" {
  let tokens = tok("{{ \"hello world\" }}")
  let ks = kinds(tokens)
  inspect!(ks, content="[OpenVar, Str(hello world), CloseVar]")
}

test "single quoted string" {
  let tokens = tok("{{ 'hello world' }}")
  let ks = kinds(tokens)
  inspect!(ks, content="[OpenVar, Str(hello world), CloseVar]")
}

test "string with escape sequences" {
  let tokens = tok("{{ \"hello\\nworld\" }}")
  let ks = kinds(tokens)
  // Escapes are passed through as-is (parser handles them)
  inspect!(ks, content="[OpenVar, Str(hello\\nworld), CloseVar]")
}

test "empty string" {
  let tokens = tok("{{ '' }}")
  let ks = kinds(tokens)
  inspect!(ks, content="[OpenVar, Str(), CloseVar]")
}

// =============================================================================
// 8. Number literals
// =============================================================================

test "integer literal" {
  let tokens = tok("{{ 42 }}")
  let ks = kinds(tokens)
  inspect!(ks, content="[OpenVar, Int(42), CloseVar]")
}

test "negative integer" {
  let tokens = tok("{{ -42 }}")
  let ks = kinds(tokens)
  inspect!(ks, content="[OpenVar, Minus, Int(42), CloseVar]")
}

test "float literal" {
  let tokens = tok("{{ 3.14 }}")
  let ks = kinds(tokens)
  inspect!(ks, content="[OpenVar, Float(3.14), CloseVar]")
}

test "float with exponent" {
  let tokens = tok("{{ 1e10 }}")
  let ks = kinds(tokens)
  inspect!(ks, content="[OpenVar, Float(1e10), CloseVar]")
}

test "float with sign exponent" {
  let tokens = tok("{{ 1.5e-3 }}")
  let ks = kinds(tokens)
  inspect!(ks, content="[OpenVar, Float(1.5e-3), CloseVar]")
}

// =============================================================================
// 9. Operators and expressions
// =============================================================================

test "arithmetic operators" {
  let tokens = tok("{{ a + b * c - d / e % f }}")
  let ks = kinds(tokens)
  inspect!(ks, content="[OpenVar, Ident(a), Plus, Ident(b), Star, Ident(c), Minus, Ident(d), Slash, Ident(e), Percent, Ident(f), CloseVar]")
}

test "comparison operators" {
  let tokens = tok("{{ a == b }}")
  let ks = kinds(tokens)
  inspect!(ks, content="[OpenVar, Ident(a), Eq, Ident(b), CloseVar]")
}

test "string concat" {
  let tokens = tok("{{ a ~ b }}")
  let ks = kinds(tokens)
  inspect!(ks, content="[OpenVar, Ident(a), Tilde, Ident(b), CloseVar]")
}

test "boolean literals" {
  let tokens = tok("{{ true and false or not true }}")
  let ks = kinds(tokens)
  inspect!(ks, content="[OpenVar, Bool(true), And, Bool(false), Or, Not, Bool(true), CloseVar]")
}

// =============================================================================
// 10. Block keywords
// =============================================================================

test "block and endblock" {
  let tokens = tok("{% block content %}body{% endblock %}")
  let ks = kinds(tokens)
  inspect!(ks, content="[OpenTag, Block, Ident(content), CloseTag, Text(body), OpenTag, Endblock, CloseTag]")
}

test "extends" {
  let tokens = tok("{% extends 'base.html' %}")
  let ks = kinds(tokens)
  inspect!(ks, content="[OpenTag, Extends, Str(base.html), CloseTag]")
}

test "macro definition" {
  let tokens = tok("{% macro input(name, value='') %}{% endmacro %}")
  let ks = kinds(tokens)
  inspect!(ks, content="[OpenTag, Macro, Ident(input), LParen, Ident(name), Comma, Ident(value), Assign, Str(), RParen, CloseTag, OpenTag, Endmacro, CloseTag]")
}

test "include" {
  let tokens = tok("{% include 'header.html' %}")
  let ks = kinds(tokens)
  inspect!(ks, content="[OpenTag, Include, Str(header.html), CloseTag]")
}

// =============================================================================
// 11. Edge cases
// =============================================================================

test "position tracking" {
  let tokens = tok("{{ name }}")
  // OpenVar at line 1, col 1  (but since it comes from text mode, the col might differ)
  let eof = tokens[tokens.length() - 1]
  @prelude.assert_eq!(eof.kind, @tpl.TokenKind::Eof)
  // EOF should appear after all content
  @prelude.assert!(eof.line >= 1)
}

test "unclosed variable tag produces error" {
  let tokens = tok("{{ name ")
  let ks = kinds(tokens)
  // Should contain an Error token
  inspect!(ks, content="[OpenVar, Ident(name), Error(Unclosed tag)]")
}

test "identifier is not keyword in expr mode" {
  // In {{ }} mode, 'if' is just an identifier, not a keyword
  let tokens = tok("{{ if }}")
  let ks = kinds(tokens)
  inspect!(ks, content="[OpenVar, Ident(if), CloseVar]")
}

test "identifier is keyword in block mode" {
  // In {% %} mode, 'if' is recognised as a keyword
  let tokens = tok("{% if %}")
  let ks = kinds(tokens)
  inspect!(ks, content="[OpenTag, If, CloseTag]")
}
