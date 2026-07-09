// Copyright (c) 2024 LinZeming
// Released under the MIT License
//
// Errors — unified error types with source-location tracking.

// ---------------------------------------------------------------------------
// Error kind
// ---------------------------------------------------------------------------

///|
/// Classification of template engine errors.
pub(all) enum ErrorKind {
  LexicalError
  SyntaxError
  EvalError
  RenderError
  FilterError
  NotFoundError
} derive(Debug)

// ---------------------------------------------------------------------------
// Source location
// ---------------------------------------------------------------------------

///|
/// A position in a template source file.
pub(all) struct SourceLocation {
  template : String
  line : Int
  column : Int
} derive(Debug)

/// Create a source location with default template name.
pub fn loc_at(line : Int, column : Int) -> SourceLocation {
  { template: "<source>", line: line, column: column }
}

// ---------------------------------------------------------------------------
// Template error
// ---------------------------------------------------------------------------

///|
/// The primary error type returned by all engine operations.
pub(all) struct TemplateError {
  kind : ErrorKind
  message : String
  location : Option[SourceLocation]
  snippet : Option[String]
} derive(Debug)

/// Create a bare error without location info.
pub fn TemplateError::new(kind : ErrorKind, message : String) -> TemplateError {
  {
    kind: kind,
    message: message,
    location: Option::None,
    snippet: Option::None,
  }
}

/// Attach source location to an error.
pub fn TemplateError::with_location(
  self : TemplateError,
  loc : SourceLocation
) -> TemplateError {
  { ..self, location: Option::Some(loc) }
}

/// Attach a source snippet to an error.
pub fn TemplateError::with_snippet(
  self : TemplateError,
  snippet : String
) -> TemplateError {
  { ..self, snippet: Option::Some(snippet) }
}

///|
/// Format the error as a human-readable string.
pub fn TemplateError::to_string(self : TemplateError) -> String {
  let kind_str = match self.kind {
    ErrorKind::LexicalError => "LexicalError"
    ErrorKind::SyntaxError => "SyntaxError"
    ErrorKind::EvalError => "EvalError"
    ErrorKind::RenderError => "RenderError"
    ErrorKind::FilterError => "FilterError"
    ErrorKind::NotFoundError => "NotFoundError"
  }
  let mut result = "Error: " + kind_str
  match self.location {
    Option::Some(loc) => {
      result = result +
        " in template \"" + loc.template + "\"" +
        " at line " + loc.line.to_string() +
        ", column " + loc.column.to_string()
    }
    Option::None => ()
  }
  result = result + "\n  " + self.message
  match self.snippet {
    Option::Some(snip) => result = result + "\n" + snip
    Option::None => ()
  }
  result
}

// ---------------------------------------------------------------------------
// Convenience constructors
// ---------------------------------------------------------------------------

/// Create a lexer error at a source position.
pub fn lex_error(msg : String, line : Int, col : Int) -> TemplateError {
  TemplateError::new(ErrorKind::LexicalError, msg)
    .with_location(loc_at(line, col))
}

/// Create a syntax error at a source position.
pub fn syntax_error(msg : String, line : Int, col : Int) -> TemplateError {
  TemplateError::new(ErrorKind::SyntaxError, msg)
    .with_location(loc_at(line, col))
}

/// Create an eval error (often without precise location).
pub fn eval_error(msg : String) -> TemplateError {
  TemplateError::new(ErrorKind::EvalError, msg)
}

/// Create a render error.
pub fn render_error(msg : String) -> TemplateError {
  TemplateError::new(ErrorKind::RenderError, msg)
}

/// Create a filter error.
pub fn filter_error(msg : String) -> TemplateError {
  TemplateError::new(ErrorKind::FilterError, msg)
}

/// Create a not-found error (template, variable, field, key).
pub fn not_found_error(msg : String) -> TemplateError {
  TemplateError::new(ErrorKind::NotFoundError, msg)
}

// ---------------------------------------------------------------------------
// Source snippet extraction
// ---------------------------------------------------------------------------

///|
/// Extract a single line from *source* for error display.
///
/// Returns a formatted string like: `  5 | {% if x > %}`.
pub fn extract_snippet(source : String, line : Int) -> String {
  if source == "" || line < 1 {
    return ""
  }
  let mut current_line = 1
  let mut line_start = 0
  let len = source.length()
  let mut i = 0
  while i < len {
    let ch = source[i]
    if ch.to_int() == '\n'.to_int() {
      if current_line == line {
        let line_content = source[line_start:i].to_owned()
        return "  " + line.to_string() + " | " + line_content
      }
      current_line = current_line + 1
      line_start = i + 1
    }
    i = i + 1
  }
  // Last line (no trailing newline).
  if current_line == line {
    let line_content = source[line_start:len].to_owned()
    return "  " + line.to_string() + " | " + line_content
  }
  ""
}
