// ---------------------------------------------------------------------------
// MoonTera — Unified Error Types
// ---------------------------------------------------------------------------

/// Error categories for template processing.
pub enum ErrorKind {
  LexicalError
  SyntaxError
  EvalError
  RenderError
  FilterError
  NotFoundError
  TypeError
}

/// Source location within a template.
pub struct SourceLocation {
  template : String
  line : Int
  column : Int
}

/// The main error type used across all modules.
pub struct TemplateError {
  kind : ErrorKind
  message : String
  location : Option[SourceLocation]
}

/// Create a new error with just a kind and message.
pub fn TemplateError::new(kind : ErrorKind, message : String) -> TemplateError {
  { kind, message, location: None }
}

/// Attach a source location to the error.
pub fn TemplateError::with_location(self : TemplateError, loc : SourceLocation) -> TemplateError {
  { ..self, location: Some(loc) }
}

/// Format the error for display.
pub fn TemplateError::to_string(self : TemplateError) -> String {
  match self.location {
    Some(loc) => {
      let kind_str = match self.kind {
        ErrorKind::LexicalError => "LexicalError"
        ErrorKind::SyntaxError => "SyntaxError"
        ErrorKind::EvalError => "EvalError"
        ErrorKind::RenderError => "RenderError"
        ErrorKind::FilterError => "FilterError"
        ErrorKind::NotFoundError => "NotFoundError"
        ErrorKind::TypeError => "TypeError"
      }
      kind_str + " in '" + loc.template + "' at line " +
      loc.line.to_string() + ", column " + loc.column.to_string() +
      ": " + self.message
    }
    None => self.message
  }
}

// ===========================================================================
// Convenience constructors
// ===========================================================================

/// Create a lexical error at a position.
pub fn lex_error(msg : String, line : Int, col : Int, tpl : String) -> TemplateError {
  TemplateError::new(ErrorKind::LexicalError, msg)
    .with_location(SourceLocation::{ template: tpl, line, column: col })
}

/// Create a syntax error at a position.
pub fn syntax_error(msg : String, line : Int, col : Int, tpl : String) -> TemplateError {
  TemplateError::new(ErrorKind::SyntaxError, msg)
    .with_location(SourceLocation::{ template: tpl, line, column: col })
}

/// Create an evaluation error.
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

/// Create a "not found" error.
pub fn not_found_error(msg : String) -> TemplateError {
  TemplateError::new(ErrorKind::NotFoundError, msg)
}

/// Create a type error.
pub fn type_error(msg : String) -> TemplateError {
  TemplateError::new(ErrorKind::TypeError, msg)
}

// ===========================================================================
// Conversion utilities
// ===========================================================================

/// Wrap a String error into a TemplateError (for gradual migration).
pub fn from_string(msg : String) -> TemplateError {
  TemplateError::new(ErrorKind::EvalError, msg)
}

/// Convert `Result[T, String]` to `Result[T, TemplateError]`.
pub fn wrap_result[T](result : Result[T, String]) -> Result[T, TemplateError] {
  match result {
    Ok(v) => Ok(v)
    Err(msg) => Err(from_string(msg))
  }
}
