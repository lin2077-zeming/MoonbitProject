// Copyright (c) 2024 LinZeming
// Released under the MIT License
//
// Template — top-level entry point for parsing and rendering templates.

pub(all) struct Template {
  nodes : Array[Node]
} derive(Debug)

// ---------------------------------------------------------------------------
// Parse
// ---------------------------------------------------------------------------

///|
/// Parse a template source string into a `Template`.
pub fn Template::parse(source : String) -> Result[Template, String] {
  let tokens_result = tokenize(source)
  let tokens = match tokens_result {
    Ok(ts) => ts
    Err(msg) => return Err("Lexer error: " + msg)
  }
  let parser = Parser::new(tokens)
  let parse_result = parser.parse_template()
  let (nodes, _rest) = match parse_result {
    Ok((ns, pp)) => (ns, pp)
    Err(msg) => return Err("Parse error: " + msg)
  }
  let _ = _rest
  Ok({ nodes: nodes })
}

// ---------------------------------------------------------------------------
// Render
// ---------------------------------------------------------------------------

///|
/// Render the template against *ctx* (uses empty loader — no includes).
pub fn Template::render(self : Template, ctx : Context) -> Result[String, String] {
  self.render_with_loader(ctx, TemplateLoader::new())
}

///|
/// Render the template with a specific *loader* for `{% include %}` support.
pub fn Template::render_with_loader(
  self : Template,
  ctx : Context,
  loader : TemplateLoader
) -> Result[String, String] {
  let renderer = Renderer::new(ctx, loader)
  renderer.render(self.nodes)
}
