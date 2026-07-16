// ---------------------------------------------------------------------------
// MoonTera — Template Loader
//
// Manages named templates and resolves inheritance chains.
// ---------------------------------------------------------------------------

pub struct TemplateLoader {
  templates : Map[String, Template]
}

pub fn TemplateLoader::new() -> TemplateLoader {
  { templates: Map::new() }
}

pub fn TemplateLoader::add_template(
  self : TemplateLoader,
  name : String,
  source : String
) -> Result[TemplateLoader, TemplateError] {
  match Template::parse(name, source) {
    Ok(tpl) => {
      self.templates[name] = tpl
      Ok(self)
    }
    Err(e) => Err(e)
  }
}

pub fn TemplateLoader::get(self : TemplateLoader, name : String) -> Option[Template] {
  self.templates.get(name)
}

/// Render a template by name, resolving the full inheritance chain.
pub fn TemplateLoader::render(
  self : TemplateLoader,
  name : String,
  ctx : Context
) -> Result[String, TemplateError] {
  match self.build_chain(name) {
    Ok(chain) => {
      // Merge blocks from root to child (child wins)
      let blocks = self.merge_blocks(chain)
      // Render root template with resolved blocks
      let root_name = chain[chain.length() - 1]
      match self.templates.get(root_name) {
        Some(root_tpl) => {
          let filtered = remove_extends(root_tpl.nodes)
          match Renderer::new(ctx).with_blocks(blocks).with_loader(self).render(filtered) {
            Ok(output) => Ok(output)
            Err(msg) => Err(render_error(msg))
          }
        }
        None => Err(not_found_error("Root template not found"))
      }
    }
    Err(e) => Err(not_found_error(e))
  }
}

// ===========================================================================
// Inheritance chain
// ===========================================================================

/// Build the inheritance chain: child (index 0) → root (index last).
fn TemplateLoader::build_chain(self : TemplateLoader, name : String) -> Result[Array[String], String] {
  let chain : Array[String] = []
  let mut current = name
  let mut safe = 0
  while safe < 20 {
    match self.templates.get(current) {
      Some(tpl) => {
        chain.push(current)
        match tpl.parent {
          Some(p) => current = p
          None => break
        }
      }
      None => return Err("Template not found: " + current)
    }
    safe = safe + 1
  }
  if safe >= 20 { return Err("Circular or too deep template inheritance") }
  Ok(chain)
}

/// Merge blocks from root (end of chain) to child (start of chain).
/// Root blocks are set first; child blocks override.
fn TemplateLoader::merge_blocks(
  self : TemplateLoader,
  chain : Array[String]
) -> Map[String, Array[Node]] {
  let blocks = Map::new()
  // Walk from root (end) to child (start)
  let mut i = chain.length()
  while i > 0 {
    i = i - 1
    match self.templates.get(chain[i]) {
      Some(tpl) => {
        // Copy all block entries from this template
        let names = tpl.block_names
        for j = 0; j < names.length(); j = j + 1 {
          let key = names[j]
          match tpl.blocks.get(key) {
            Some(body) => blocks[key] = body
            None => ()
          }
        }
      }
      None => ()
    }
  }
  blocks
}

/// Remove Node::Extends from a node array (already handled).
fn remove_extends(nodes : Array[Node]) -> Array[Node] {
  let result : Array[Node] = []
  for i = 0; i < nodes.length(); i = i + 1 {
    match nodes[i] {
      Node::Extends(_) => ()
      _ => result.push(nodes[i])
    }
  }
  result
}
