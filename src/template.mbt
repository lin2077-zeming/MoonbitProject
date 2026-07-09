// Copyright (c) 2024 LinZeming
// Released under the MIT License
//
// Template — top-level entry point for parsing and rendering templates.
//
// A `Template` wraps a compiled list of `Node`s and provides a convenient
// `render` method that ties together lexing, parsing, and rendering.

// ---------------------------------------------------------------------------
// Template struct
// ---------------------------------------------------------------------------

///|
/// A compiled template ready for rendering.
pub(all) struct Template {
  nodes : Array[Node]
} derive(Debug)

// ---------------------------------------------------------------------------
// Parse
// ---------------------------------------------------------------------------

///|
/// Parse a template source string into a `Template`.
///
/// Internally runs the lexer and parser.
pub fn Template::parse(source : String) -> Result[Template, String] {
  // 1. Lex.
  let tokens_result = tokenize(source)
  let tokens = match tokens_result {
    Ok(ts) => ts
    Err(msg) => return Err("Lexer error: " + msg)
  }

  // 2. Parse.
  let parser = Parser::new(tokens)
  let parse_result = parser.parse_template()
  let (nodes, _rest) = match parse_result {
    Ok((ns, pp)) => (ns, pp)
    Err(msg) => return Err("Parse error: " + msg)
  }
  let _ = _rest  // unused parser state

  Ok({ nodes: nodes })
}

// ---------------------------------------------------------------------------
// Render
// ---------------------------------------------------------------------------

///|
/// Render the template against *ctx* and return the output string.
pub fn Template::render(self : Template, ctx : Context) -> Result[String, String] {
  let renderer = Renderer::new(ctx)
  renderer.render(self.nodes)
}
