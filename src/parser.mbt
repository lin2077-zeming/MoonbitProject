// ---------------------------------------------------------------------------
// MoonTera — Parser
//
// Converts a token stream into an AST (Template with Nodes).
// Expression parsing uses Pratt's algorithm (top-down operator precedence).
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Parser struct
// ---------------------------------------------------------------------------

/// Parser state — holds tokens, current position, and accumulated errors.
pub struct Parser {
  tokens : Array[Token]
  mut pos : Int
}

/// Create a new parser over a token array.
pub fn Parser::new(tokens : Array[Token]) -> Parser {
  { tokens, pos: 0 }
}

// ===========================================================================
// Basic parser methods
// ===========================================================================

/// Peek at the current token. Returns None at EOF.
pub fn Parser::peek(self : Parser) -> Option[Token] {
  if self.pos < self.tokens.length() && self.tokens[self.pos].kind != TokenKind::Eof {
    Some(self.tokens[self.pos])
  } else {
    None
  }
}

/// Peek ahead by `offset` tokens. Returns None if out of bounds.
pub fn Parser::peek_at(self : Parser, offset : Int) -> Option[Token] {
  let idx = self.pos + offset
  if idx < self.tokens.length() && self.tokens[idx].kind != TokenKind::Eof {
    Some(self.tokens[idx])
  } else {
    None
  }
}

/// Consume and return the current token. Returns None at EOF.
pub fn Parser::advance(self : Parser) -> Option[Token] {
  if self.pos < self.tokens.length() && self.tokens[self.pos].kind != TokenKind::Eof {
    let token = self.tokens[self.pos]
    self.pos = self.pos + 1
    Some(token)
  } else {
    None
  }
}

/// Expect a token matching a predicate; return it or an error.
pub fn Parser::expect(
  self : Parser,
  predicate : (Token) -> Bool
) -> Result[Token, String] {
  match self.peek() {
    Some(token) => if predicate(token) {
      let _ = self.advance()
      Ok(token)
    } else {
      Err("Unexpected token")
    }
    None => Err("Expected token but reached end of input")
  }
}

/// Return the current position in the token stream.
pub fn Parser::current_pos(self : Parser) -> Int {
  self.pos
}

// ===========================================================================
// Template parsing (entry point)
// ===========================================================================

/// Parse a full template into a Template with statement-level Nodes.
/// Extracts `{% extends %}` as parent name and `{% block %}` definitions.
pub fn Parser::parse_template(self : Parser, name : String) -> Result[Template, String] {
  let tokens = self.tokens
  match parse_nodes_until(tokens, 0, []) {
    Ok((_pos, nodes)) => {
      // Extract extends (first tag only)
      let parent = extract_extends(nodes)
      let (blocks, block_names) = extract_blocks(nodes)
      Ok(Template::{ name, nodes, parent, blocks, block_names })
    }
    Err(e) => Err(e)
  }
}

/// Scan nodes for the first `Node::Extends` and return the parent name.
fn extract_extends(nodes : Array[Node]) -> Option[String] {
  // Look for Extends at the beginning (before any non-Text node)
  for i = 0; i < nodes.length(); i = i + 1 {
    match nodes[i] {
      Node::Text(_) => continue // skip leading whitespace/text
      Node::Extends(name) => return Some(name)
      _ => return None // first non-Text, non-Extends → no parent
    }
  }
  None
}

/// Extract top-level block nodes into a Map and a name list.
fn extract_blocks(nodes : Array[Node]) -> (Map[String, Array[Node]], Array[String]) {
  let blocks = Map::new()
  let names : Array[String] = []
  for i = 0; i < nodes.length(); i = i + 1 {
    match nodes[i] {
      Node::Block(name, body) => {
        blocks[name] = body
        names.push(name)
      }
      _ => ()
    }
  }
  (blocks, names)
}

// ===========================================================================
// Node parsing loop — parses nodes until a stop keyword appears after OpenTag
// ===========================================================================

/// Parse nodes until we encounter an OpenTag followed by one of `stop_kinds`
/// or reach Eof.  `stop_kinds` is an array of TokenKind keywords (Elif, Else,
/// Endif, etc.) that signal the end of the current block.
///
/// Returns (new_pos, Array[Node]).  The caller is responsible for consuming
/// the stop-tag tokens after this function returns.
fn parse_nodes_until(
  tokens : Array[Token],
  pos : Int,
  stop_kinds : Array[TokenKind]
) -> Result[(Int, Array[Node]), String] {
  let nodes = []
  let mut p = pos

  while p < tokens.length() && tokens[p].kind != TokenKind::Eof {
    let token = tokens[p]

    match token.kind {
      // ── Plain text ──────────────────────────────────────────
      TokenKind::Text(text) => {
        nodes.push(Node::Text(text))
        p = p + 1
      }

      // ── Variable output: {{ expr }} ─────────────────────────
      TokenKind::OpenVar => {
        p = p + 1
        match parse_until_delimiter(tokens, p, TokenKind::CloseVar, "}}") {
          Ok((new_p, expr)) => {
            p = new_p
            nodes.push(Node::Output(expr))
          }
          Err(e) => return Err(e)
        }
      }

      // ── Tag block: {% ... %} ────────────────────────────────
      TokenKind::OpenTag => {
        p = p + 1 // skip {%
        // Peek at the keyword after OpenTag
        if p >= tokens.length() {
          return Err("Unexpected end of input after '{%'")
        }
        match tokens[p].kind {
          // ── If / elif / else / endif ──────────────────
          TokenKind::If => {
            match parse_if_block(tokens, p) {
              Ok((new_p, node)) => {
                p = new_p
                nodes.push(node)
              }
              Err(e) => return Err(e)
            }
          }
          // ── For / endfor ────────────────────────────
          TokenKind::For => {
            match parse_for_block(tokens, p) {
              Ok((new_p, node)) => {
                p = new_p
                nodes.push(node)
              }
              Err(e) => return Err(e)
            }
          }
          // ── Block / endblock ──────────────────────
          TokenKind::Block => {
            match parse_block_tag(tokens, p) {
              Ok((new_p, node)) => {
                p = new_p
                nodes.push(node)
              }
              Err(e) => return Err(e)
            }
          }
          // ── Macro / endmacro ─────────────────────
          TokenKind::Macro => {
            match parse_macro_tag(tokens, p) {
              Ok((new_p, node)) => {
                p = new_p
                nodes.push(node)
              }
              Err(e) => return Err(e)
            }
          }
          // ── Include ──────────────────────────────
          TokenKind::Include => {
            p = p + 1 // skip Include
            let after_keyword = skip_skippable(tokens, p)
            match parse_until_delimiter(tokens, after_keyword, TokenKind::CloseTag, "%}") {
              Ok((new_p, expr)) => {
                p = new_p
                match expr {
                  Expr::Literal(Value::Str(tpl_name)) => {
                    nodes.push(Node::Include(tpl_name))
                  }
                  _ => return Err("Expected string literal after 'include'")
                }
              }
              Err(e) => return Err(e)
            }
          }
          // ── Extends: create a simple node ──────────
          TokenKind::Extends => {
            p = p + 1 // skip Extends
            let after_keyword = skip_skippable(tokens, p)
            match parse_until_delimiter(tokens, after_keyword, TokenKind::CloseTag, "%}") {
              Ok((new_p, expr)) => {
                p = new_p
                match expr {
                  Expr::Literal(Value::Str(parent_name)) => {
                    nodes.push(Node::Extends(parent_name))
                  }
                  _ => return Err("Expected string literal after 'extends'")
                }
              }
              Err(e) => return Err(e)
            }
          }
          // ── Stop keywords — return to caller ──────────
          _ => {
            // Check if this keyword is in our stop list
            let mut should_stop = false
            for i = 0; i < stop_kinds.length(); i = i + 1 {
              if tokens[p].kind == stop_kinds[i] {
                should_stop = true
                break
              }
            }
            if should_stop {
              // Return position pointing to the OpenTag, so the caller
              // can consume OpenTag + keyword + CloseTag.
              return Ok((p - 1, nodes))
            }
            // Otherwise skip the entire tag
            match skip_tag_content(tokens, p - 1) {
              Ok(new_p) => p = new_p
              Err(e) => return Err(e)
            }
          }
        }
      }

      // ── Other tokens at top level are unexpected ────────────
      _ => return Err("Unexpected token at template level: " + debug_token(token))
    }
  }

  Ok((p, nodes))
}

// ===========================================================================
// If-block parsing
// ===========================================================================

/// Parse an if / elif / else / endif block.
/// Called after consuming `{%` — `pos` points to the `If` token.
fn parse_if_block(tokens : Array[Token], pos : Int) -> Result[(Int, Node), String] {
  let p = pos + 1 // skip If

  // ── Parse condition expression ────────────────────────────────
  match parse_until_delimiter(tokens, p, TokenKind::CloseTag, "%}") {
    Ok((p, condition)) => {
      // ── Parse then-body until Elif, Else, or Endif ────────────
      let stop_kinds = [TokenKind::Elif, TokenKind::Else, TokenKind::Endif]
      match parse_nodes_until(tokens, p, stop_kinds) {
        Ok((p, then_body)) => {
          // ── Parse elif branches (loop until no more elif) ─────
          let elif_branches = []
          let mut p = p
          let mut saw_elif = is_open_tag_keyword(tokens, p, TokenKind::Elif)
          while saw_elif {
            p = p + 2 // skip OpenTag + Elif
            match parse_until_delimiter(tokens, p, TokenKind::CloseTag, "%}") {
              Ok((new_p, elif_cond)) => {
                p = new_p
                let elif_stops = [TokenKind::Elif, TokenKind::Else, TokenKind::Endif]
                match parse_nodes_until(tokens, p, elif_stops) {
                  Ok((new_p, elif_body)) => {
                    p = new_p
                    elif_branches.push((elif_cond, elif_body))
                    saw_elif = is_open_tag_keyword(tokens, p, TokenKind::Elif)
                  }
                  Err(e) => return Err(e)
                }
              }
              Err(e) => return Err(e)
            }
          }

          // ── Parse else branch (optional) ──────────────────────
          let else_body = []
          let mut p = p
          if is_open_tag_keyword(tokens, p, TokenKind::Else) {
            p = p + 1 // skip OpenTag
            p = p + 1 // skip Else
            if p < tokens.length() && tokens[p].kind == TokenKind::CloseTag {
              p = p + 1 // skip %}
            } else {
              return Err("Expected '%}' after 'else'")
            }
            let else_stops = [TokenKind::Endif]
            match parse_nodes_until(tokens, p, else_stops) {
              Ok((new_p, body)) => {
                p = new_p
                let mut i = 0
                while i < body.length() {
                  else_body.push(body[i])
                  i = i + 1
                }
              }
              Err(e) => return Err(e)
            }
          }

          // ── Consume Endif ─────────────────────────────────────
          if is_open_tag_keyword(tokens, p, TokenKind::Endif) {
            p = p + 1 // skip OpenTag
            p = p + 1 // skip Endif
            if p < tokens.length() && tokens[p].kind == TokenKind::CloseTag {
              p = p + 1 // skip %}
              return Ok((p, Node::If(condition, then_body, elif_branches, else_body)))
            }
          }
          Err("Expected '{% endif %}'")
        }
        Err(e) => Err(e)
      }
    }
    Err(e) => Err(e)
  }
}

// ===========================================================================
// For-block parsing
// ===========================================================================

/// Parse a `{% for var in expr %} body {% endfor %}` block.
/// Called after consuming `{%` — `pos` points to the `For` token.
fn parse_for_block(tokens : Array[Token], pos : Int) -> Result[(Int, Node), String] {
  let mut p = pos + 1 // skip For

  // ── Read loop variable name ──────────────────────────────────
  if p >= tokens.length() {
    return Err("Expected loop variable after 'for'")
  }
  let var_name = match tokens[p].kind {
    TokenKind::Ident(name) => name
    _ => return Err("Expected identifier after 'for'")
  }
  p = p + 1 // skip variable name

  // ── Expect 'in' keyword ─────────────────────────────────────
  if p >= tokens.length() || tokens[p].kind != TokenKind::In {
    return Err("Expected 'in' after loop variable")
  }
  p = p + 1 // skip 'in'

  // ── Parse iterator expression until CloseTag ────────────────
  match parse_until_delimiter(tokens, p, TokenKind::CloseTag, "%}") {
    Ok((after_iter, iter_expr)) => {
      p = after_iter
      // ── Parse body until Endfor ─────────────────────────────
      let stop_kinds = [TokenKind::Endfor]
      match parse_nodes_until(tokens, p, stop_kinds) {
        Ok((after_body, body)) => {
          p = after_body
          // ── Consume Endfor ──────────────────────────────────
          if is_open_tag_keyword(tokens, p, TokenKind::Endfor) {
            p = p + 1 // skip OpenTag
            p = p + 1 // skip Endfor
            if p < tokens.length() && tokens[p].kind == TokenKind::CloseTag {
              p = p + 1 // skip %}
              return Ok((p, Node::For(var_name, iter_expr, body)))
            }
          }
          Err("Expected '{% endfor %}'")
        }
        Err(e) => Err(e)
      }
    }
    Err(e) => Err(e)
  }
}

// ===========================================================================
// Block-tag parsing
// ===========================================================================

/// Parse a `{% block name %} body {% endblock %}` block.
fn parse_block_tag(tokens : Array[Token], pos : Int) -> Result[(Int, Node), String] {
  let mut p = pos + 1 // skip Block

  // ── Read block name ──────────────────────────────────────────
  if p >= tokens.length() {
    return Err("Expected block name after 'block'")
  }
  let block_name = match tokens[p].kind {
    TokenKind::Ident(name) => name
    _ => return Err("Expected identifier after 'block'")
  }
  p = p + 1

  // ── Consume CloseTag ─────────────────────────────────────────
  if p < tokens.length() && tokens[p].kind == TokenKind::CloseTag {
    p = p + 1
  } else {
    return Err("Expected '%}' after block name")
  }

  // ── Parse body until Endblock ────────────────────────────────
  let stop_kinds = [TokenKind::Endblock]
  match parse_nodes_until(tokens, p, stop_kinds) {
    Ok((after_body, body)) => {
      p = after_body
      // Consume Endblock
      if is_open_tag_keyword(tokens, p, TokenKind::Endblock) {
        p = p + 1 // skip OpenTag
        p = p + 1 // skip Endblock
        if p < tokens.length() && tokens[p].kind == TokenKind::CloseTag {
          p = p + 1 // skip %}
          return Ok((p, Node::Block(block_name, body)))
        }
      }
      Err("Expected '{% endblock %}'")
    }
    Err(e) => Err(e)
  }
}

/// Check if the token at `pos` is OpenTag followed by the given keyword.
// ===========================================================================
// Macro-tag parsing
// ===========================================================================

/// Parse `{% macro name(p1, p2) %} body {% endmacro %}`.
fn parse_macro_tag(tokens : Array[Token], pos : Int) -> Result[(Int, Node), String] {
  let mut p = pos + 1 // skip Macro

  // ── Read macro name ──────────────────────────────────────────
  if p >= tokens.length() { return Err("Expected macro name") }
  let macro_name = match tokens[p].kind {
    TokenKind::Ident(name) => name
    _ => return Err("Expected identifier after 'macro'")
  }
  p = p + 1

  // ── Read parameter list ( LParen Ident, Ident, ... RParen ) ──
  let params : Array[String] = []
  if p < tokens.length() && tokens[p].kind == TokenKind::LParen {
    p = p + 1 // skip (
    while p < tokens.length() && tokens[p].kind != TokenKind::RParen {
      match tokens[p].kind {
        TokenKind::Ident(name) => {
          params.push(name)
          p = p + 1
          // Skip comma
          if p < tokens.length() && tokens[p].kind == TokenKind::Comma {
            p = p + 1
          }
        }
        _ => return Err("Expected parameter name in macro definition")
      }
    }
    if p < tokens.length() && tokens[p].kind == TokenKind::RParen {
      p = p + 1 // skip )
    } else {
      return Err("Expected ')' after macro parameters")
    }
  }

  // ── Consume CloseTag ─────────────────────────────────────────
  if p < tokens.length() && tokens[p].kind == TokenKind::CloseTag {
    p = p + 1
  } else {
    return Err("Expected '%}' after macro header")
  }

  // ── Parse body until Endmacro ────────────────────────────────
  let stop_kinds = [TokenKind::Endmacro]
  match parse_nodes_until(tokens, p, stop_kinds) {
    Ok((after_body, body)) => {
      p = after_body
      if is_open_tag_keyword(tokens, p, TokenKind::Endmacro) {
        p = p + 1 // skip OpenTag
        p = p + 1 // skip Endmacro
        if p < tokens.length() && tokens[p].kind == TokenKind::CloseTag {
          p = p + 1 // skip %}
          return Ok((p, Node::Macro(macro_name, params, body)))
        }
      }
      Err("Expected '{% endmacro %}'")
    }
    Err(e) => Err(e)
  }
}

fn is_open_tag_keyword(tokens : Array[Token], pos : Int, kind : TokenKind) -> Bool {
  pos < tokens.length() &&
  tokens[pos].kind == TokenKind::OpenTag &&
  pos + 1 < tokens.length() &&
  tokens[pos + 1].kind == kind
}

// ===========================================================================
// Helpers for parse_template
// ===========================================================================

/// Collect tokens until a closing delimiter, then parse as expression.
fn parse_until_delimiter(
  tokens : Array[Token],
  start : Int,
  close_kind : TokenKind,
  close_name : String
) -> Result[(Int, Expr), String] {
  let expr_tokens = []
  let mut pos = start
  while pos < tokens.length() && tokens[pos].kind != close_kind && tokens[pos].kind != TokenKind::Eof {
    expr_tokens.push(tokens[pos])
    pos = pos + 1
  }
  if pos >= tokens.length() || tokens[pos].kind == TokenKind::Eof {
    return Err("Unclosed delimiter — expected " + close_name)
  }
  pos = pos + 1 // skip closing delimiter
  match parse_expression(expr_tokens) {
    Ok(expr) => Ok((pos, expr))
    Err(e) => Err(e)
  }
}

/// Skip an unknown tag from OpenTag to CloseTag.  `pos` points to OpenTag.
fn skip_tag_content(tokens : Array[Token], pos : Int) -> Result[Int, String] {
  let mut p = pos + 1 // skip OpenTag
  while p < tokens.length() && tokens[p].kind != TokenKind::CloseTag && tokens[p].kind != TokenKind::Eof {
    p = p + 1
  }
  if p >= tokens.length() || tokens[p].kind == TokenKind::Eof {
    return Err("Unclosed tag — expected '%}'")
  }
  Ok(p + 1) // skip CloseTag
}

// ===========================================================================
// Expression parsing (public API)
// ===========================================================================

/// Parse an expression from a token array (used inside {{ }} or {% %}).
/// Uses Pratt parsing with operator precedence.
pub fn parse_expression(tokens : Array[Token]) -> Result[Expr, String] {
  let pos = skip_skippable(tokens, 0)
  if pos >= tokens.length() || tokens[pos].kind == TokenKind::Eof {
    return Err("Unexpected end of input in expression")
  }
  match parse_expr(tokens, pos, 0) {
    Ok((_next_pos, expr)) => {
      let end_pos = skip_skippable(tokens, _next_pos)
      if end_pos < tokens.length() && tokens[end_pos].kind != TokenKind::Eof &&
         !is_delimiter(tokens, end_pos) {
        Err("Unexpected token after expression")
      } else {
        Ok(expr)
      }
    }
    Err(e) => Err(e)
  }
}

// ===========================================================================
// Pratt parsing core
// ===========================================================================

/// Parse expression with minimum precedence. Returns (new_pos, Expr).
fn parse_expr(tokens : Array[Token], pos : Int, min_prec : Int) -> Result[(Int, Expr), String] {
  match parse_prefix(tokens, pos) {
    Ok((pos, left)) => parse_infix(tokens, pos, left, min_prec)
    Err(e) => Err(e)
  }
}

// ===========================================================================
// Infix/postfix parsing loop (recursive)
// ===========================================================================

fn parse_infix(
  tokens : Array[Token],
  pos : Int,
  left : Expr,
  min_prec : Int
) -> Result[(Int, Expr), String] {
  let pos = skip_skippable(tokens, pos)
  if pos >= tokens.length() || tokens[pos].kind == TokenKind::Eof || is_delimiter(tokens, pos) {
    return Ok((pos, left))
  }

  let token = tokens[pos]

  // ── Binary operators ─────────────────────────────────────────────
  match BinOpKind::from_token_kind(token.kind) {
    Some(op) => {
      let prec = op.precedence()
      if prec >= min_prec {
        match parse_expr(tokens, pos + 1, prec + 1) {
          Ok((next_pos, right)) => return parse_infix(tokens, next_pos, Expr::BinOp(left, op, right), min_prec)
          Err(e) => return Err(e)
        }
      } else {
        return Ok((pos, left))
      }
    }
    None => ()
  }

  // ── Member access: .ident ────────────────────────────────────────
  if token.kind == TokenKind::Dot {
    let after = skip_skippable(tokens, pos + 1)
    if after < tokens.length() {
      match tokens[after].kind {
        TokenKind::Ident(name) => parse_infix(tokens, after + 1, Expr::Member(left, name), min_prec)
        _ => Err("Expected identifier after '.'")
      }
    } else {
      Err("Expected identifier after '.'")
    }
  } else if token.kind == TokenKind::LParen {
    // ── Function call: (args) ───────────────────────────────────
    match parse_arg_list(tokens, pos + 1) {
      Ok((next_pos, args)) => match get_call_name(left) {
        Ok(name) => parse_infix(tokens, next_pos, Expr::Call(name, args), min_prec)
        Err(e) => Err(e)
      }
      Err(e) => Err(e)
    }
  } else if token.kind == TokenKind::Pipe {
    // ── Filter: | filter_name  or  | filter_name:arg ────────────
    let after_pipe = skip_skippable(tokens, pos + 1)
    if after_pipe < tokens.length() {
      match tokens[after_pipe].kind {
        TokenKind::Ident(filter_name) => {
          let mut next_pos = after_pipe + 1
          let args = []
          if next_pos < tokens.length() && tokens[next_pos].kind == TokenKind::Colon {
            match parse_expr(tokens, next_pos + 1, 0) {
              Ok((p, arg_expr)) => {
                next_pos = p
                args.push(arg_expr)
                // Support additional colon-separated args
                while next_pos < tokens.length() && tokens[next_pos].kind == TokenKind::Colon {
                  match parse_expr(tokens, next_pos + 1, 0) {
                    Ok((p, a)) => {
                      next_pos = p
                      args.push(a)
                    }
                    Err(_) => break
                  }
                }
              }
              Err(_) => ()
            }
          }
          parse_infix(tokens, next_pos, Expr::Filter(left, filter_name, args), min_prec)
        }
        _ => Err("Expected filter name after '|'")
      }
    } else {
      Err("Expected filter name after '|'")
    }
  } else {
    Ok((pos, left))
  }
}

// ===========================================================================
// Prefix parsing
// ===========================================================================

fn parse_prefix(tokens : Array[Token], pos : Int) -> Result[(Int, Expr), String] {
  if pos >= tokens.length() {
    return Err("Unexpected end of input")
  }
  let token = tokens[pos]

  if token.kind == TokenKind::Minus {
    match parse_expr(tokens, pos + 1, 6) {
      Ok((next_pos, inner)) => Ok((next_pos, Expr::UnaryOp(UnaryOpKind::Neg, inner)))
      Err(e) => Err(e)
    }
  } else if token.kind == TokenKind::Not {
    match parse_expr(tokens, pos + 1, 6) {
      Ok((next_pos, inner)) => Ok((next_pos, Expr::UnaryOp(UnaryOpKind::Not, inner)))
      Err(e) => Err(e)
    }
  } else if token.kind == TokenKind::LParen {
    match parse_expr(tokens, pos + 1, 0) {
      Ok((next_pos, inner)) => {
        let after = skip_skippable(tokens, next_pos)
        if after < tokens.length() && tokens[after].kind == TokenKind::RParen {
          Ok((after + 1, inner))
        } else {
          Err("Expected ')'")
        }
      }
      Err(e) => Err(e)
    }
  } else {
    parse_primary_token(token, pos)
  }
}

// ===========================================================================
// Primary token → expression
// ===========================================================================

fn parse_primary_token(token : Token, pos : Int) -> Result[(Int, Expr), String] {
  match token.kind {
    TokenKind::Str(s) => Ok((pos + 1, Expr::Literal(Value::Str(s))))
    TokenKind::Int(s) => Ok((pos + 1, Expr::Literal(Value::Int(parse_int64(s)))))
    TokenKind::Float(s) => Ok((pos + 1, Expr::Literal(Value::Float(parse_double(s)))))
    TokenKind::Bool(b) => Ok((pos + 1, Expr::Literal(Value::Bool(b))))
    TokenKind::Ident(name) => {
      if name == "null" || name == "nil" {
        Ok((pos + 1, Expr::Literal(Value::Null)))
      } else {
        Ok((pos + 1, Expr::Variable(name)))
      }
    }
    _ => Err("Unexpected token: " + debug_token(token))
  }
}

// ===========================================================================
// Helpers
// ===========================================================================

fn skip_skippable(tokens : Array[Token], pos : Int) -> Int {
  let mut p = pos
  while p < tokens.length() {
    match tokens[p].kind {
      TokenKind::Text(_) => p = p + 1
      _ => break
    }
  }
  p
}

fn is_delimiter(tokens : Array[Token], pos : Int) -> Bool {
  if pos >= tokens.length() {
    return true
  }
  let kind = tokens[pos].kind
  kind == TokenKind::CloseVar || kind == TokenKind::CloseTag
}

fn parse_arg_list(tokens : Array[Token], pos : Int) -> Result[(Int, Array[Expr]), String] {
  let args = []
  let mut p = skip_skippable(tokens, pos)
  if p < tokens.length() && tokens[p].kind == TokenKind::RParen {
    return Ok((p + 1, args))
  }
  while p < tokens.length() {
    p = skip_skippable(tokens, p)
    if p >= tokens.length() || tokens[p].kind == TokenKind::RParen {
      break
    }
    match parse_expr(tokens, p, 0) {
      Ok((next_pos, arg)) => {
        p = next_pos
        args.push(arg)
        p = skip_skippable(tokens, p)
        if p < tokens.length() && tokens[p].kind == TokenKind::Comma {
          p = p + 1
        }
      }
      Err(e) => return Err(e)
    }
  }
  if p < tokens.length() && tokens[p].kind == TokenKind::RParen {
    Ok((p + 1, args))
  } else {
    Err("Expected ')' to close argument list")
  }
}

fn get_call_name(expr : Expr) -> Result[String, String] {
  match expr {
    Expr::Variable(name) => Ok(name)
    _ => Err("Expected function name before '('")
  }
}

// ===========================================================================
// Number parsing (manual — avoids external dependencies)
// ===========================================================================

fn parse_int64(s : String) -> Int64 {
  let mut result = 0L
  for i = 0; i < s.length(); i = i + 1 {
    let c = s[i]
    let digit = c.to_int() - '0'.to_int()
    result = result * 10L + digit.to_int64()
  }
  result
}

fn parse_double(s : String) -> Double {
  let mut dot_pos = -1
  for i = 0; i < s.length(); i = i + 1 {
    if s[i] == '.' {
      dot_pos = i
      break
    }
  }
  if dot_pos < 0 {
    parse_int64(s).to_double()
  } else {
    let int_part = parse_int64(s[0:dot_pos].to_owned()).to_double()
    let frac_part = parse_int64(s[dot_pos + 1:s.length()].to_owned()).to_double()
    let mut frac_div = 1.0
    for _i = 0; _i < s.length() - dot_pos - 1; _i = _i + 1 {
      frac_div = frac_div * 10.0
    }
    int_part + frac_part / frac_div
  }
}

fn debug_token(token : Token) -> String {
  match token.kind {
    TokenKind::Text(_) => "Text"
    TokenKind::Ident(s) => "Ident('" + s + "')"
    TokenKind::Str(s) => "Str('" + s + "')"
    TokenKind::Int(s) => "Int(" + s + ")"
    TokenKind::Float(s) => "Float(" + s + ")"
    TokenKind::Eof => "EOF"
    _ => "token"
  }
}
