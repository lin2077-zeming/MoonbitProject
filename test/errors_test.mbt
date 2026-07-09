// Copyright (c) 2024 LinZeming
// Released under the MIT License
//
// Black-box tests for unified error handling.

// =============================================================================
// 1. ErrorKind classification
// =============================================================================

test "ErrorKind values exist" {
  // Verify all error kinds are constructable.
  let _ = @tpl.ErrorKind::LexicalError
  let _ = @tpl.ErrorKind::SyntaxError
  let _ = @tpl.ErrorKind::EvalError
  let _ = @tpl.ErrorKind::RenderError
  let _ = @tpl.ErrorKind::FilterError
  let _ = @tpl.ErrorKind::NotFoundError
  @prelude.assert_true!(true)
}

// =============================================================================
// 2. SourceLocation
// =============================================================================

test "SourceLocation creation" {
  let loc = @tpl.SourceLocation::{
    template: "test.html",
    line: 5,
    column: 12,
  }
  @prelude.assert_eq!(loc.template, "test.html")
  @prelude.assert_eq!(loc.line, 5)
  @prelude.assert_eq!(loc.column, 12)
}

test "loc_at helper" {
  let loc = @tpl.loc_at(10, 3)
  @prelude.assert_eq!(loc.line, 10)
  @prelude.assert_eq!(loc.column, 3)
  @prelude.assert_eq!(loc.template, "<source>")
}

// =============================================================================
// 3. TemplateError construction
// =============================================================================

test "TemplateError new" {
  let err = @tpl.TemplateError::new(@tpl.ErrorKind::LexicalError, "bad token")
  let s = err.to_string()
  @prelude.assert!(s.contains("LexicalError"))
  @prelude.assert!(s.contains("bad token"))
}

test "TemplateError with location" {
  let loc = @tpl.loc_at(3, 8)
  let err = @tpl.TemplateError::new(@tpl.ErrorKind::SyntaxError, "expected ')'")
    .with_location(loc)
  let s = err.to_string()
  @prelude.assert!(s.contains("line 3"))
  @prelude.assert!(s.contains("column 8"))
  @prelude.assert!(s.contains("expected ')'"))
}

test "TemplateError with snippet" {
  let err = @tpl.TemplateError::new(@tpl.ErrorKind::EvalError, "undefined var")
    .with_snippet("  5 | {{ missing }}")
  let s = err.to_string()
  @prelude.assert!(s.contains("undefined var"))
  @prelude.assert!(s.contains("{{ missing }}"))
}

// =============================================================================
// 4. Convenience constructors
// =============================================================================

test "lex_error" {
  let err = @tpl.lex_error("unclosed string", 1, 10)
  let s = err.to_string()
  @prelude.assert!(s.contains("LexicalError"))
  @prelude.assert!(s.contains("unclosed string"))
}

test "syntax_error" {
  let err = @tpl.syntax_error("expected endif", 4, 1)
  let s = err.to_string()
  @prelude.assert!(s.contains("SyntaxError"))
  @prelude.assert!(s.contains("expected endif"))
}

test "eval_error" {
  let err = @tpl.eval_error("variable not found: x")
  let s = err.to_string()
  @prelude.assert!(s.contains("EvalError"))
  @prelude.assert!(s.contains("variable not found"))
}

test "render_error" {
  let err = @tpl.render_error("template not found: base")
  let s = err.to_string()
  @prelude.assert!(s.contains("RenderError"))
  @prelude.assert!(s.contains("template not found"))
}

test "filter_error" {
  let err = @tpl.filter_error("expected string argument")
  let s = err.to_string()
  @prelude.assert!(s.contains("FilterError"))
  @prelude.assert!(s.contains("expected string"))
}

test "not_found_error" {
  let err = @tpl.not_found_error("macro 'button' not found")
  let s = err.to_string()
  @prelude.assert!(s.contains("NotFoundError"))
  @prelude.assert!(s.contains("macro 'button'"))
}

// =============================================================================
// 5. Source snippet extraction
// =============================================================================

test "extract snippet from source" {
  let src = "line1\nline2\n{% if x > %}\nline4"
  let snippet = @tpl.extract_snippet(src, 3)
  @prelude.assert!(snippet.contains("3"))
  @prelude.assert!(snippet.contains("if x >"))
}

test "extract snippet first line" {
  let src = "hello world\nline2"
  let snippet = @tpl.extract_snippet(src, 1)
  @prelude.assert!(snippet.contains("1"))
  @prelude.assert!(snippet.contains("hello world"))
}

test "extract snippet out of range" {
  let src = "only one line"
  let snippet = @tpl.extract_snippet(src, 99)
  @prelude.assert_eq!(snippet, "")
}

// =============================================================================
// 6. Error from parsing (syntax error)
// =============================================================================

test "parse missing endif returns TemplateError" {
  let result = @tpl.Template::parse("{% if x %}no endif")
  match result {
    Ok(_) => @prelude.assert_false!(true)
    Err(err) => {
      let s = err.to_string()
      @prelude.assert!(s.contains("SyntaxError"))
    }
  }
}

// =============================================================================
// 7. Error from rendering (undefined variable)
// =============================================================================

test "render undefined variable returns TemplateError" {
  let tpl_result = @tpl.Template::parse("{{ missing }}")
  let tpl = match tpl_result {
    Ok(t) => t
    Err(_) => @prelude.fail("parse should succeed")
  }
  let ctx = @tpl.Context::new()
  let result = tpl.render(ctx)
  match result {
    Ok(_) => @prelude.assert_false!(true)
    Err(err) => {
      let s = err.to_string()
      @prelude.assert!(s.contains("RenderError"))
    }
  }
}

// =============================================================================
// 8. Parser::make_error with location
// =============================================================================

test "Parser make_error has location" {
  let tokens_result = @tpl.lexer.tokenize("{{ x }}")
  let tokens = match tokens_result {
    Ok(ts) => ts
    Err(_) => @prelude.fail("lexer failed")
  }
  let p = @tpl.Parser::new(tokens)
  let err = p.make_error(@tpl.ErrorKind::SyntaxError, "test error")
  let s = err.to_string()
  @prelude.assert!(s.contains("line 1"))
}
