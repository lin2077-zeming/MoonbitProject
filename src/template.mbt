// Copyright (c) 2024 LinZeming
// Released under the MIT License
//
// Template — top-level entry point for parsing and rendering templates.
//
// Public API methods return `TemplateError` for structured error reporting
// with source-location tracking.

pub(all) struct Template {
  nodes : Array[Node]
} derive(Debug)

// ---------------------------------------------------------------------------
// Parse
// ---------------------------------------------------------------------------

///|
/// Parse a template source string into a `Template`.
/// Returns `TemplateError` with location info on failure.
pub fn Template::parse(source : String) -> Result[Template, TemplateError] {
  let tokens_result = tokenize(source)
  let tokens = match tokens_result {
    Ok(ts) => ts
    Err(msg) => return Err(
      TemplateError::new(ErrorKind::LexicalError, "Lexer error: " + msg)
    )
  }
  let parser = Parser::new(tokens)
  let parse_result = parser.parse_template()
  let (nodes, _rest) = match parse_result {
    Ok((ns, pp)) => (ns, pp)
    Err(msg) => return Err(
      TemplateError::new(ErrorKind::SyntaxError, "Parse error: " + msg)
    )
  }
  let _ = _rest
  Ok({ nodes: nodes })
}

// ---------------------------------------------------------------------------
// Render
// ---------------------------------------------------------------------------

///|
/// Render with empty loader (no includes).
pub fn Template::render(
  self : Template,
  ctx : Context
) -> Result[String, TemplateError] {
  self.render_with_loader(ctx, TemplateLoader::new())
}

///|
/// Render with a specific loader for `{% include %}` support.
pub fn Template::render_with_loader(
  self : Template,
  ctx : Context,
  loader : TemplateLoader
) -> Result[String, TemplateError] {
  let renderer = Renderer::new(ctx, loader)
  let result = renderer.render(self.nodes)
  match result {
    Ok(s) => Ok(s)
    Err(msg) => Err(TemplateError::new(ErrorKind::RenderError, msg))
  }
}
