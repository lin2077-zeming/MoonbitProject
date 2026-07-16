// ---------------------------------------------------------------------------
// MoonTera — Lexer white-box tests
// ---------------------------------------------------------------------------

/// Extract token kinds from tokens array.
fn kinds(tokens : Array[Token]) -> Array[TokenKind] {
  tokens.map(fn(t) { t.kind })
}

/// Tokenize and extract kinds.
fn tokenize_kinds(input : String) -> Array[TokenKind] {
  let lexer = Lexer::new(input)
  let tokens = lexer.tokenize()
  kinds(tokens)
}

/// Tokenize and return full tokens.
fn tokenize_all(input : String) -> Array[Token] {
  let lexer = Lexer::new(input)
  lexer.tokenize()
}

// ===========================================================================
// 1. Plain text
// ===========================================================================

test "plain text — single line" {
  let tokens = tokenize_all("Hello World")
  assert_true!(tokens.length() == 2) // Text + Eof
  assert_true!(tokens[0].kind == TokenKind::Text("Hello World"))
  assert_true!(tokens[1].kind == TokenKind::Eof)
}

test "plain text — empty input" {
  let tokens = tokenize_all("")
  assert_true!(tokens.length() == 1)
  assert_true!(tokens[0].kind == TokenKind::Eof)
}

test "plain text — multiline preserves newlines" {
  let tokens = tokenize_all("line1\nline2")
  assert_true!(tokens[0].kind == TokenKind::Text("line1\nline2"))
}

// ===========================================================================
// 2. Simple variable output
// ===========================================================================

test "simple variable — {{ name }}" {
  let tokens = tokenize_all("{{ name }}")
  // OpenVar + Ident + CloseVar + Eof = 4 tokens
  assert_true!(tokens.length() == 4)
}

test "variable with surrounding text" {
  let tokens = tokenize_all("Hello {{ name }}!")
  assert_true!(tokens.length() == 6) // Text("Hello ") + OpenVar + Ident + CloseVar + Text("!") + Eof
  assert_true!(tokens[0].kind == TokenKind::Text("Hello "))
  assert_true!(tokens[1].kind == TokenKind::OpenVar)
  assert_true!(tokens[2].kind == TokenKind::Ident("name"))
  assert_true!(tokens[3].kind == TokenKind::CloseVar)
  assert_true!(tokens[4].kind == TokenKind::Text("!"))
}

test "multiple variables" {
  let tokens = tokenize_all("{{ a }} and {{ b }}")
  assert_true!(tokens[1].kind == TokenKind::Ident("a"))
  assert_true!(tokens[5].kind == TokenKind::Ident("b"))
}

test "empty variable — {{ }}" {
  let tokens = tokenize_all("{{ }}")
  assert_true!(tokens[0].kind == TokenKind::OpenVar)
  assert_true!(tokens[1].kind == TokenKind::CloseVar)
}

// ===========================================================================
// 3. Filters
// ===========================================================================

test "filter — {{ name | upper }}" {
  let tokens = tokenize_all("{{ name | upper }}")
  assert_true!(tokens[2].kind == TokenKind::Pipe)
  assert_true!(tokens[3].kind == TokenKind::Ident("upper"))
}

test "filter chain — {{ value | lower | trim }}" {
  let tokens = tokenize_all("{{ value | lower | trim }}")
  assert_true!(tokens[2].kind == TokenKind::Pipe)
  assert_true!(tokens[3].kind == TokenKind::Ident("lower"))
  assert_true!(tokens[4].kind == TokenKind::Pipe)
  assert_true!(tokens[5].kind == TokenKind::Ident("trim"))
}

test "filter with arg — {{ price | round:2 }}" {
  let tokens = tokenize_all("{{ price | round:2 }}")
  assert_true!(tokens[4].kind == TokenKind::Colon)
  assert_true!(tokens[5].kind == TokenKind::Int("2"))
}

test "filter with string arg" {
  let tokens = tokenize_all("{{ name | default:\"N/A\" }}")
  assert_true!(tokens[5].kind == TokenKind::Str("N/A"))
}

// ===========================================================================
// 4. if / elif / else / endif
// ===========================================================================

test "if tag — basic" {
  let tokens = tokenize_all("{% if x %}yes{% endif %}")
  assert_true!(tokens[1].kind == TokenKind::If)
  assert_true!(tokens[2].kind == TokenKind::Ident("x"))
  assert_true!(tokens[4].kind == TokenKind::Text("yes"))
  assert_true!(tokens[6].kind == TokenKind::Endif)
}

test "if / elif / else — full chain" {
  let tokens = tokenize_all("{% if a %}A{% elif b %}B{% else %}C{% endif %}")
  assert_true!(tokens[1].kind == TokenKind::If)
  assert_true!(tokens[6].kind == TokenKind::Elif)
  assert_true!(tokens[11].kind == TokenKind::Else)
  assert_true!(tokens[15].kind == TokenKind::Endif)
}

test "if with comparison" {
  let tokens = tokenize_all("{% if a == 1 and b != 2 %}ok{% endif %}")
  assert_true!(tokens[3].kind == TokenKind::Eq)
  assert_true!(tokens[4].kind == TokenKind::Int("1"))
  assert_true!(tokens[5].kind == TokenKind::And)
  assert_true!(tokens[7].kind == TokenKind::NotEq)
  assert_true!(tokens[8].kind == TokenKind::Int("2"))
}

// ===========================================================================
// 5. for / endfor loops
// ===========================================================================

test "for loop — basic" {
  let tokens = tokenize_all("{% for item in items %}x{% endfor %}")
  assert_true!(tokens[1].kind == TokenKind::For)
  assert_true!(tokens[2].kind == TokenKind::Ident("item"))
  assert_true!(tokens[3].kind == TokenKind::In)
  assert_true!(tokens[4].kind == TokenKind::Ident("items"))
}

test "for loop — key, value unpacking" {
  let tokens = tokenize_all("{% for key, value in map %}item{% endfor %}")
  assert_true!(tokens[2].kind == TokenKind::Ident("key"))
  assert_true!(tokens[3].kind == TokenKind::Comma)
  assert_true!(tokens[4].kind == TokenKind::Ident("value"))
}

// ===========================================================================
// 6. block / endblock
// ===========================================================================

test "block tag" {
  let tokens = tokenize_all("{% block content %}body{% endblock %}")
  assert_true!(tokens[1].kind == TokenKind::Block)
  assert_true!(tokens[2].kind == TokenKind::Ident("content"))
}

// ===========================================================================
// 7. extends / include
// ===========================================================================

test "extends tag" {
  let tokens = tokenize_all("{% extends \"base.html\" %}")
  assert_true!(tokens[1].kind == TokenKind::Extends)
  assert_true!(tokens[2].kind == TokenKind::Str("base.html"))
}

test "include tag" {
  let tokens = tokenize_all("{% include \"header.html\" %}")
  assert_true!(tokens[1].kind == TokenKind::Include)
}

// ===========================================================================
// 8. macro / endmacro
// ===========================================================================

test "macro tag" {
  let tokens = tokenize_all("{% macro input(name, type) %}...{% endmacro %}")
  assert_true!(tokens[1].kind == TokenKind::Macro)
  assert_true!(tokens[2].kind == TokenKind::Ident("input"))
  assert_true!(tokens[3].kind == TokenKind::LParen)
}

// ===========================================================================
// 9. Comments — skipped
// ===========================================================================

test "comment is skipped — single line" {
  let tokens = tokenize_all("{# this is a comment #}")
  assert_true!(tokens.length() == 1) // Only Eof
  assert_true!(tokens[0].kind == TokenKind::Eof)
}

test "comment is skipped — surrounded by text" {
  let tokens = tokenize_all("before{# comment #}after")
  assert_true!(tokens.length() == 3)
  assert_true!(tokens[0].kind == TokenKind::Text("before"))
  assert_true!(tokens[1].kind == TokenKind::Text("after"))
  assert_true!(tokens[2].kind == TokenKind::Eof)
}

test "comment is skipped — multiline" {
  let input = "{# this is a\n   multiline comment #}content"
  let tokens = tokenize_all(input)
  assert_true!(tokens[0].kind == TokenKind::Text("content"))
}

test "comment inside variable context" {
  let tokens = tokenize_all("{{ x }}{# note #}")
  // Should have tokens for {{ x }} plus Eof, comment skipped
  assert_true!(tokens.length() == 4) // Text("")? Let's just check key tokens
  let mut found_var = false
  for i = 0; i < tokens.length(); i = i + 1 {
    if tokens[i].kind == TokenKind::Ident("x") {
      found_var = true
    }
  }
  assert_true!(found_var)
}

// ===========================================================================
// 10. String literals
// ===========================================================================

test "string — double-quoted" {
  let tokens = tokenize_all("{{ \"hello\" }}")
  assert_true!(tokens[1].kind == TokenKind::Str("hello"))
}

test "string — single-quoted" {
  let tokens = tokenize_all("{{ 'world' }}")
  assert_true!(tokens[1].kind == TokenKind::Str("world"))
}

test "string — escape sequences" {
  let tokens = tokenize_all("{{ \"line1\\nline2\" }}")
  assert_true!(tokens[1].kind == TokenKind::Str("line1\nline2"))
}

test "string — unclosed produces Error token" {
  // Input: {{ "oops }}  → quote is 'oops }}, then {{ ok }}
  // But the entire thing is in one variable context...
  let tokens = tokenize_all("{{ \"oops }}{{ ok }}")
  // Check that an Error token exists in the stream
  let mut found_error = false
  for i = 0; i < tokens.length(); i = i + 1 {
    match tokens[i].kind {
      TokenKind::Error(_) => found_error = true
      _ => ()
    }
  }
  assert_true!(found_error)
}

// ===========================================================================
// 11. Number literals (stored as raw strings)
// ===========================================================================

test "integer literal" {
  let tokens = tokenize_all("{{ 42 }}")
  assert_true!(tokens[1].kind == TokenKind::Int("42"))
}

test "float literal" {
  let tokens = tokenize_all("{{ 3.14 }}")
  assert_true!(tokens[1].kind == TokenKind::Float("3.14"))
}

test "integer literal — multi-digit" {
  let tokens = tokenize_all("{{ 123456 }}")
  assert_true!(tokens[1].kind == TokenKind::Int("123456"))
}

test "dot alone is not a float" {
  let tokens = tokenize_all("{{ a.b }}")
  assert_true!(tokens[1].kind == TokenKind::Ident("a"))
  assert_true!(tokens[2].kind == TokenKind::Dot)
  assert_true!(tokens[3].kind == TokenKind::Ident("b"))
}

// ===========================================================================
// 12. Boolean literals
// ===========================================================================

test "boolean — true and false" {
  let tokens = tokenize_all("{% if true and not false %}ok{% endif %}")
  assert_true!(tokens[2].kind == TokenKind::Bool(true))
  assert_true!(tokens[3].kind == TokenKind::And)
  assert_true!(tokens[4].kind == TokenKind::Not)
  assert_true!(tokens[5].kind == TokenKind::Bool(false))
}

// ===========================================================================
// 13. Operators
// ===========================================================================

test "arithmetic operators" {
  let tokens = tokenize_all("{{ a + b - c * d / e % f }}")
  assert_true!(tokens[2].kind == TokenKind::Plus)
  assert_true!(tokens[4].kind == TokenKind::Minus)
  assert_true!(tokens[6].kind == TokenKind::Star)
  assert_true!(tokens[8].kind == TokenKind::Slash)
  assert_true!(tokens[10].kind == TokenKind::Percent)
}

test "comparison operators" {
  let tokens = tokenize_all("{{ a < b and c > d }}")
  assert_true!(tokens[2].kind == TokenKind::Lt)
  assert_true!(tokens[6].kind == TokenKind::Gt)
}

test "two-char operators — == != <= >=" {
  let tokens = tokenize_all("{% if a == 1 and b != 2 and c <= 3 and d >= 4 %}{% endif %}")
  assert_true!(tokens[3].kind == TokenKind::Eq)
  assert_true!(tokens[7].kind == TokenKind::NotEq)
  assert_true!(tokens[11].kind == TokenKind::LtEq)
  assert_true!(tokens[15].kind == TokenKind::GtEq)
}

// ===========================================================================
// 14. Punctuation
// ===========================================================================

test "parentheses and comma" {
  let tokens = tokenize_all("{{ f(a, b) }}")
  assert_true!(tokens[2].kind == TokenKind::LParen)
  assert_true!(tokens[4].kind == TokenKind::Comma)
  assert_true!(tokens[6].kind == TokenKind::RParen)
}

test "dot — member access" {
  let tokens = tokenize_all("{{ user.name }}")
  assert_true!(tokens[1].kind == TokenKind::Ident("user"))
  assert_true!(tokens[2].kind == TokenKind::Dot)
  assert_true!(tokens[3].kind == TokenKind::Ident("name"))
}

// ===========================================================================
// 15. Position tracking
// ===========================================================================

test "position — text starts at line 1, col 1" {
  let tokens = tokenize_all("Hello")
  assert_true!(tokens[0].line == 1)
  assert_true!(tokens[0].col == 1)
}

test "position — variable on second line" {
  let tokens = tokenize_all("\n{{ x }}")
  // Text("\n") at 1:1
  assert_true!(tokens[0].line == 1)
  // OpenVar at 2:1
  assert_true!(tokens[1].kind == TokenKind::OpenVar)
  assert_true!(tokens[1].line == 2)
}

// ===========================================================================
// 16. Error tokens
// ===========================================================================

test "error — unclosed variable tag at EOF" {
  let tokens = tokenize_all("{{ name")
  let mut has_error = false
  for i = 0; i < tokens.length(); i = i + 1 {
    match tokens[i].kind {
      TokenKind::Error(_) => has_error = true
      _ => ()
    }
  }
  assert_true!(has_error)
}

test "error — unclosed block tag at EOF" {
  let tokens = tokenize_all("{% if x")
  let mut has_error = false
  for i = 0; i < tokens.length(); i = i + 1 {
    match tokens[i].kind {
      TokenKind::Error(_) => has_error = true
      _ => ()
    }
  }
  assert_true!(has_error)
}

test "error — unexpected character" {
  let tokens = tokenize_all("{{ @ }}")
  let mut found_error = false
  for i = 0; i < tokens.length(); i = i + 1 {
    match tokens[i].kind {
      TokenKind::Error(_) => found_error = true
      _ => ()
    }
  }
  assert_true!(found_error)
}

// ===========================================================================
// 17. Edge cases
// ===========================================================================

test "adjacent delimiters" {
  let tokens = tokenize_all("{{ a }}{{ b }}")
  assert_true!(tokens[2].kind == TokenKind::CloseVar)
  assert_true!(tokens[3].kind == TokenKind::OpenVar)
}

test "tag with extra whitespace" {
  let tokens = tokenize_all("  {{   name   }}  ")
  // Text("  ") at start
  assert_true!(tokens[0].kind == TokenKind::Text("  "))
  // Ident("name") inside
  assert_true!(tokens[2].kind == TokenKind::Ident("name"))
  // Text("  ") at end
  assert_true!(tokens[4].kind == TokenKind::Text("  "))
}

// ===========================================================================
// 18. Real-world template
// ===========================================================================

test "real template — HTML with mixed content" {
  let input =
    "<html>\n" +
    "<head><title>{% block title %}Default{% endblock %}</title></head>\n" +
    "<body>\n" +
    "  {% for item in items %}\n" +
    "    <li>{{ item.name | upper }}</li>\n" +
    "  {% endfor %}\n" +
    "</body>\n" +
    "</html>"
  let tokens = tokenize_all(input)
  assert_true!(tokens.length() > 0)
  assert_true!(tokens[tokens.length() - 1].kind == TokenKind::Eof)
}
