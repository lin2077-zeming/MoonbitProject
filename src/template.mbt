// ---------------------------------------------------------------------------
// MoonTera — Template (public API)
// ---------------------------------------------------------------------------

/// Parse a template source string into a compiled Template.
pub fn Template::parse(name : String, source : String) -> Result[Template, TemplateError] {
  let lexer = Lexer::new(source)
  let tokens = lexer.tokenize()
  let parser = Parser::new(tokens)
  match parser.parse_template(name) {
    Ok(tpl) => Ok(tpl)
    Err(msg) => Err(syntax_error(msg, 1, 1, name))
  }
}

/// Render this template with the given context.
pub fn Template::render(self : Template, ctx : Context) -> Result[String, TemplateError] {
  let renderer = Renderer::new(ctx)
  match renderer.render(self.nodes) {
    Ok(output) => Ok(output)
    Err(msg) => Err(render_error(msg))
  }
}
