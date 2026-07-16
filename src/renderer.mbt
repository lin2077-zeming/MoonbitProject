// ---------------------------------------------------------------------------
// MoonTera — Renderer
//
// Walks the Node AST, evaluates embedded expressions against a Context,
// and produces the final rendered string.
// ---------------------------------------------------------------------------

/// The renderer holds a context for variable lookup and accumulates output.
pub struct Renderer {
  ctx : Context
  filters : FilterRegistry
  output : String
  block_overrides : Map[String, Array[Node]]
  loader : Option[TemplateLoader]
}

/// Create a new renderer with the given context and default filters.
pub fn Renderer::new(ctx : Context) -> Renderer {
  { ctx, filters: FilterRegistry::default(), output: "", block_overrides: Map::new(), loader: None }
}

/// Set block overrides for inheritance rendering.
pub fn Renderer::with_blocks(self : Renderer, overrides : Map[String, Array[Node]]) -> Renderer {
  { ..self, block_overrides: overrides }
}

/// Set a template loader (for includes).
pub fn Renderer::with_loader(self : Renderer, ldr : TemplateLoader) -> Renderer {
  { ..self, loader: Some(ldr) }
}

/// Render an array of nodes into a single output string.
pub fn Renderer::render(self : Renderer, nodes : Array[Node]) -> Result[String, String] {
  match self.render_nodes(nodes) {
    Ok(r) => Ok(r.output)
    Err(e) => Err(e)
  }
}

/// Render an array of nodes, returning the updated Renderer.
/// Used internally for recursive rendering of block bodies (if, for, etc.).
pub fn Renderer::render_nodes(self : Renderer, nodes : Array[Node]) -> Result[Renderer, String] {
  let mut r = self
  for i = 0; i < nodes.length(); i = i + 1 {
    match r.render_node(nodes[i]) {
      Ok(next) => r = next
      Err(e) => return Err(e)
    }
  }
  Ok(r)
}

/// Render a single node, appending its output to the internal buffer.
pub fn Renderer::render_node(self : Renderer, node : Node) -> Result[Renderer, String] {
  match node {
    // ── Text: append verbatim ───────────────────────────────────────
    Node::Text(text) => Ok(self.append(text))

    // ── Output: evaluate expression and append ──────────────────────
    Node::Output(expr) => match evaluate(expr, self.ctx, self.filters) {
      Ok(val) => Ok(self.append(val.to_string()))
      Err(e) => Err(e)
    }

    // ── If / elif / else ────────────────────────────────────────────
    Node::If(condition, then_body, elif_branches, else_body) => {
      match evaluate(condition, self.ctx, self.filters) {
        Ok(val) => {
          if val.is_truthy() {
            return self.render_nodes(then_body)
          }
          // Try elif branches in order
          for i = 0; i < elif_branches.length(); i = i + 1 {
            let (elif_cond, elif_body) = elif_branches[i]
            match evaluate(elif_cond, self.ctx, self.filters) {
              Ok(v) => if v.is_truthy() {
                return self.render_nodes(elif_body)
              }
              Err(e) => return Err(e)
            }
          }
          // Try else branch
          if else_body.length() > 0 {
            return self.render_nodes(else_body)
          }
          // Nothing matched — return unchanged
          Ok(self)
        }
        Err(e) => Err(e)
      }
    }

    // ── For loop: {% for var in expr %} body {% endfor %} ──────────
    Node::For(var_name, iter_expr, body) => {
      match evaluate(iter_expr, self.ctx, self.filters) {
        Ok(iter_val) => match iter_val {
          Value::Array(items) => {
            let len = items.length()
            if len == 0 {
              return Ok(self) // empty array → no output
            }
            let mut output = self.output
            for i = 0; i < len; i = i + 1 {
              // Create child context with loop variables
              let child_ctx = Context::new_child(self.ctx)
              child_ctx.set(var_name, items[i])
              // Build the loop object
              let loop_obj = Map::new()
              loop_obj["index"] = Value::Int((i + 1).to_int64())
              loop_obj["index0"] = Value::Int(i.to_int64())
              loop_obj["first"] = Value::Bool(i == 0)
              loop_obj["last"] = Value::Bool(i == len - 1)
              loop_obj["length"] = Value::Int(len.to_int64())
              child_ctx.set("loop", Value::Object(loop_obj))
              // Render body with child context
              let child_renderer = Renderer::{ ctx: child_ctx, filters: self.filters, output: "", block_overrides: self.block_overrides, loader: self.loader }
              match child_renderer.render_nodes(body) {
                Ok(updated) => output = output + updated.output
                Err(e) => return Err(e)
              }
            }
            Ok(Renderer::{ ctx: self.ctx, filters: self.filters, output, block_overrides: self.block_overrides, loader: self.loader })
          }
          _ => Err("For loop requires an array, got: " + iter_val.to_string())
        }
        Err(e) => Err(e)
      }
    }

    // ── Block: use override if available, else default body ────────
    Node::Block(name, default_body) => {
      match self.block_overrides.get(name) {
        Some(override_body) => self.render_nodes(override_body)
        None => self.render_nodes(default_body)
      }
    }

    // ── Extends: handled by inheritance resolution, skip at render ──
    Node::Extends(_) => Ok(self)

    // ── Macro definition: register in context, no output ───────────
    Node::Macro(name, params, body) => {
      let m = MacroDef::{ name, params, body }
      self.ctx.set_macro(m)
      Ok(self)
    }

    // ── Include: render another template with current context ──────
    Node::Include(tpl_name) => {
      match self.loader {
        Some(ldr) => match ldr.get(tpl_name) {
          Some(tpl) => match tpl.render(self.ctx) {
            Ok(included_output) => {
              Ok(Renderer::{ ..self, output: self.output + included_output })
            }
            Err(_) => Err("Failed to render included template")
          }
          None => Err("Included template not found: " + tpl_name)
        }
        None => Err("Cannot include — no TemplateLoader available")
      }
    }

    // ── Not yet implemented ─────────────────────────────────────────
    Node::FilterBlock(_, _, _) => Err("'filter' block rendering not yet implemented")
  }
}

/// Append a string to the output buffer.
fn Renderer::append(self : Renderer, s : String) -> Renderer {
  { ..self, output: self.output + s }
}
