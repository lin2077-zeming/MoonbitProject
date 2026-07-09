// Copyright (c) 2024 LinZeming
// Released under the MIT License
//
// Renderer — walks an AST and produces the final output string.
//
// The renderer evaluates `Output` expressions against a `Context` and
// concatenates `Text` nodes.  Other node types will be added incrementally.

// ---------------------------------------------------------------------------
// Renderer struct
// ---------------------------------------------------------------------------

///|
/// Template renderer — converts `Node` trees into a string.
pub(all) struct Renderer {
  evaluator : Evaluator
  output : StringBuilder
} derive(Debug)

// ---------------------------------------------------------------------------
// Constructor
// ---------------------------------------------------------------------------

///|
/// Create a new renderer with the given *ctx*.
pub fn Renderer::new(ctx : Context) -> Renderer {
  {
    evaluator: Evaluator::new(ctx),
    output: StringBuilder::new(),
  }
}

// ---------------------------------------------------------------------------
// Top-level render entry point
// ---------------------------------------------------------------------------

///|
/// Render a list of nodes and return the final output string.
pub fn Renderer::render(
  self : Renderer,
  nodes : Array[Node]
) -> Result[String, String] {
  let r = self.render_nodes(nodes)
  match r {
    Ok(renderer) => Ok(renderer.output.to_string())
    Err(msg) => Err(msg)
  }
}

///|
/// Render a list of nodes, returning the updated renderer.
fn Renderer::render_nodes(
  self : Renderer,
  nodes : Array[Node]
) -> Result[Renderer, String] {
  let mut r = self
  for node in nodes {
    let result = r.render_node(node)
    r = match result {
      Ok(renderer) => renderer
      Err(msg) => return Err(msg)
    }
  }
  Ok(r)
}

// ---------------------------------------------------------------------------
// Single-node rendering
// ---------------------------------------------------------------------------

///|
/// Render a single node into the output buffer.
pub fn Renderer::render_node(
  self : Renderer,
  node : Node
) -> Result[Renderer, String] {
  match node {
    // -- Text: append directly --------------------------------------------
    Text(content) => {
      let output = self.output
      output.write_string(content)
      Ok({ ..self, output })
    }

    // -- Output: evaluate expression, convert to string, append ----------
    Output(expr) => {
      let eval_result = self.evaluator.eval(expr)
      let val = match eval_result {
        Ok(v) => v
        Err(msg) => return Err(msg)
      }
      let output = self.output
      output.write_string(val.to_string())
      Ok({ ..self, output })
    }

    // -- If: condition with elif / else branches ---------------------------
    If(condition, then_body, elif_branches, else_body) => {
      // Evaluate the main condition.
      let eval_result = self.evaluator.eval(condition)
      let cond_val = match eval_result {
        Ok(v) => v
        Err(msg) => return Err(msg)
      }
      if cond_val.is_truthy() {
        return self.render_nodes(then_body)
      }

      // Try each elif branch.
      for branch in elif_branches {
        let branch_cond = match branch.condition {
          Option::Some(expr) => expr
          Option::None => continue
        }
        let branch_result = self.evaluator.eval(branch_cond)
        let branch_val = match branch_result {
          Ok(v) => v
          Err(msg) => return Err(msg)
        }
        if branch_val.is_truthy() {
          return self.render_nodes(branch.body)
        }
      }

      // Fall through to else body.
      if else_body.length() > 0 {
        return self.render_nodes(else_body)
      }
      Ok(self)
    }

    // -- For loop ----------------------------------------------------------
    For(loop_var, iterable, body) => {
      let iter_result = self.evaluator.eval(iterable)
      let iter_val = match iter_result {
        Ok(v) => v
        Err(msg) => return Err(msg)
      }
      match iter_val {
        Array(items) => {
          let len = items.length()
          if len == 0 {
            return Ok(self)
          }
          let mut r = self
          for i = 0; i < len; i = i + 1 {
            // Build loop builtins.
            let loop_obj : Map[String, Value] = Map::new()
            loop_obj["index"] = Int((i + 1).to_int64())
            loop_obj["index0"] = Int(i.to_int64())
            loop_obj["first"] = Bool(i == 0)
            loop_obj["last"] = Bool(i + 1 == len)
            loop_obj["length"] = Int(len.to_int64())

            // Create child context with loop var + loop builtins.
            let child_ctx = Context::new_child(r.evaluator.ctx)
              .set(loop_var, items[i])
              .set("loop", Object(loop_obj))
            r = { ..r, evaluator: Evaluator::new(child_ctx) }
            let render_result = r.render_nodes(body)
            r = match render_result {
              Ok(rr) => rr
              Err(msg) => return Err(msg)
            }
            // Restore evaluator context for next iteration
            // (the render result contains the updated evaluator state;
            //  we just need to keep the output buffer).
          }
          Ok(r)
        }
        _ => Err("For loop requires an array, got: " + iter_val.type_name())
      }
    }

    // -- Not implemented yet -----------------------------------------------
    Block(_, _) => Err("blocks not yet implemented")
    Extends(_) => Err("extends not yet implemented")
    Include(_) => Err("include not yet implemented")
    Macro(_, _, _) => Err("macros not yet implemented")
    FilterBlock(_, _, _) => Err("filter blocks not yet implemented")
  }
}
