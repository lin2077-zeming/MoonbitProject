// Copyright (c) 2024 LinZeming
// Released under the MIT License
//
// Parser — converts a stream of `Token`s into a template AST.
//
// The parser reads tokens produced by the lexer and builds an abstract
// syntax tree consisting of `Node`s and `Expr`s.  It uses a recursive-
// descent strategy with a Pratt parser for expressions.

// ---------------------------------------------------------------------------
// Parser state
// ---------------------------------------------------------------------------

///|
/// Parser state — holds the token stream and current position.
///
/// All methods that modify state return a `(result, Parser)` pair so the
/// caller always has the latest state without needing mutable references.
pub(all) struct Parser {
  tokens : Array[Token]
  pos : Int
  errors : Array[String]
} derive(Debug)

// ---------------------------------------------------------------------------
// Constructors
// ---------------------------------------------------------------------------

///|
/// Create a new parser from a token array (typically produced by
/// `tokenize`).
pub fn Parser::new(tokens : Array[Token]) -> Parser {
  {
    tokens,
    pos: 0,
    errors: Array::new(),
  }
}

// ---------------------------------------------------------------------------
// Token inspection (read-only)
// ---------------------------------------------------------------------------

///|
/// Return the token at the current position, or `None` if at EOF.
pub fn Parser::peek(self : Parser) -> Token? {
  if self.pos < self.tokens.length() {
    Some(self.tokens[self.pos])
  } else {
    None
  }
}

///|
/// Look ahead *offset* tokens from the current position.
/// `peek_at(0)` is equivalent to `peek()`.
pub fn Parser::peek_at(self : Parser, offset : Int) -> Token? {
  let idx = self.pos + offset
  if idx >= 0 && idx < self.tokens.length() {
    Some(self.tokens[idx])
  } else {
    None
  }
}

///|
/// Return the current position in the token stream (0-indexed).
pub fn Parser::current_pos(self : Parser) -> Int {
  self.pos
}

// ---------------------------------------------------------------------------
// Token consumption (state-modifying)
// ---------------------------------------------------------------------------

///|
/// Consume and return the current token, advancing the position.
/// Returns `None` if already at EOF.
pub fn Parser::advance(self : Parser) -> (Token?, Parser) {
  if self.pos < self.tokens.length() {
    let tok = self.tokens[self.pos]
    (Some(tok), { ..self, pos: self.pos + 1 })
  } else {
    (None, self)
  }
}

///|
/// Consume the current token if it satisfies *check*, otherwise record an
/// error and return `Err(message)`.
pub fn Parser::expect(
  self : Parser,
  check : (Token) -> Bool,
  message : String
) -> Result[(Token, Parser), String] {
  let tok_opt = self.peek()
  match tok_opt {
    None => {
      let err_msg = message + " — unexpected EOF"
      self.error(err_msg) |> ignore
      Err(err_msg)
    }
    Some(tok) => {
      if check(tok) {
        let (consumed, next) = self.advance()
        match consumed {
          Some(t) => Ok((t, next))
          None => {
            let err_msg = message + " — unexpected EOF"
            self.error(err_msg) |> ignore
            Err(err_msg)
          }
        }
      } else {
        let err_msg = message + " (got unexpected token at line " +
          tok.line.to_string() + ", col " + tok.col.to_string() + ")"
        self.error(err_msg) |> ignore
        Err(err_msg)
      }
    }
  }
}

///|
/// Record a parse error without consuming input.
pub fn Parser::error(self : Parser, msg : String) -> Parser {
  let errs = self.errors
  errs.push(msg)
  { ..self, errors: errs }
}

///|
/// Return all accumulated parse errors.
pub fn Parser::get_errors(self : Parser) -> Array[String] {
  self.errors
}

// ---------------------------------------------------------------------------
// Pratt expression parser — operator precedence
// ---------------------------------------------------------------------------

/// Binding power for prefix operators.
fn prefix_bp(kind : TokenKind) -> Int? {
  match kind {
    TokenKind::Not => Some(7)
    TokenKind::Minus => Some(7)
    _ => None
  }
}

/// Binding power for infix / postfix operators.
/// Returns `(left_bp, right_bp)`.
fn infix_bp(kind : TokenKind) -> (Int, Int)? {
  match kind {
    TokenKind::Pipe    => Some((1, 2))
    TokenKind::Or      => Some((2, 3))
    TokenKind::And     => Some((3, 4))
    TokenKind::Eq |
    TokenKind::NotEq |
    TokenKind::Lt |
    TokenKind::Gt |
    TokenKind::LtEq |
    TokenKind::GtEq    => Some((4, 5))
    TokenKind::Plus |
    TokenKind::Minus   => Some((5, 6))
    TokenKind::Star |
    TokenKind::Slash |
    TokenKind::Percent => Some((6, 7))
    TokenKind::Dot     => Some((8, 9))
    TokenKind::LBracket => Some((8, 9))
    TokenKind::LParen  => Some((8, 9))
    _ => None
  }
}

/// Map a `TokenKind` to the corresponding `BinOpKind`.
fn token_to_binop(kind : TokenKind) -> BinOpKind? {
  match kind {
    TokenKind::Plus   => Some(BinOpKind::Add)
    TokenKind::Minus  => Some(BinOpKind::Sub)
    TokenKind::Star   => Some(BinOpKind::Mul)
    TokenKind::Slash  => Some(BinOpKind::Div)
    TokenKind::Percent => Some(BinOpKind::Mod)
    TokenKind::Eq     => Some(BinOpKind::Eq)
    TokenKind::NotEq  => Some(BinOpKind::Neq)
    TokenKind::Lt     => Some(BinOpKind::Lt)
    TokenKind::Gt     => Some(BinOpKind::Gt)
    TokenKind::LtEq   => Some(BinOpKind::Le)
    TokenKind::GtEq   => Some(BinOpKind::Ge)
    TokenKind::And    => Some(BinOpKind::And)
    TokenKind::Or     => Some(BinOpKind::Or)
    _ => None
  }
}

/// Map a `TokenKind` to the corresponding `UnaryOpKind`.
fn token_to_unary(kind : TokenKind) -> UnaryOpKind? {
  match kind {
    TokenKind::Not => Some(UnaryOpKind::Not)
    TokenKind::Minus => Some(UnaryOpKind::Neg)
    _ => None
  }
}

/// String label for a `TokenKind` (for error messages).
fn token_kind_label(kind : TokenKind) -> String {
  match kind {
    TokenKind::RParen => "')'"
    TokenKind::Comma => "','"
    _ => "delimiter"
  }
}

// ---------------------------------------------------------------------------
// Expression parsing
// ---------------------------------------------------------------------------

///|
/// Parse an expression with the given minimum binding power (Pratt parser).
pub fn Parser::parse_expression(
  self : Parser,
  min_bp : Int
) -> Result[(Expr, Parser), String] {
  // 1. Parse prefix (primary expression or unary op).
  let init_result = self.parse_prefix()
  let (init_expr, init_p) = match init_result {
    Ok((e, p)) => (e, p)
    Err(msg) => return Err(msg)
  }
  let mut lhs = init_expr
  let mut p = init_p

  // 2. Loop: handle infix / postfix operators.
  // State-driven loop using for.
  let result = for _state = (lhs, p) {
    lhs = _state.0
    p = _state.1
    let tok_opt = p.peek()
    let tok = match tok_opt {
      Some(t) => t
      None => break (lhs, p)
    }

    let bp_opt = infix_bp(tok.kind)
    let (lbp, rbp) = match bp_opt {
      Some(bp) => bp
      None => break (lhs, p)
    }

    if lbp < min_bp {
      break (lhs, p)
    }

    match tok.kind {
      // -- Pipe (filter) ------------------------------------------------
      TokenKind::Pipe => {
        let (_, p2) = p.advance()
        p = p2
        let name_opt = p.peek()
        let filter_name = match name_opt {
          Some(t2) => match t2.kind {
            TokenKind::Ident(n) => {
              let (_, p3) = p.advance()
              p = p3
              n
            }
            _ => return Err("Expected filter name after '|'")
          }
          None => return Err("Expected filter name after '|'")
        }
        let args_result = parse_filter_args(p)
        let (args, p4) = match args_result {
          Ok((a, pp)) => (a, pp)
          Err(msg) => return Err(msg)
        }
        p = p4
        lhs = Filter(lhs, filter_name, args)
        continue (lhs, p)
      }

      // -- Dot (member access) ------------------------------------------
      TokenKind::Dot => {
        let (_, p2) = p.advance()
        p = p2
        let field_opt = p.peek()
        match field_opt {
          Some(t2) => match t2.kind {
            TokenKind::Ident(field) => {
              let (_, p3) = p.advance()
              p = p3
              lhs = Member(lhs, field)
              continue (lhs, p)
            }
            _ => return Err("Expected field name after '.'")
          }
          None => return Err("Expected field name after '.'")
        }
      }

      // -- LBracket (index access) --------------------------------------
      TokenKind::LBracket => {
        let (_, p2) = p.advance()
        p = p2
        let idx_result = p.parse_expression(0)
        let (idx_expr, p3) = match idx_result {
          Ok((e, pp)) => (e, pp)
          Err(msg) => return Err(msg)
        }
        p = p3
        let expect_result = p.expect(
          fn(tok_val : Token) -> Bool { tok_val.kind == TokenKind::RBracket },
          "Expected ']'",
        )
        match expect_result {
          Ok((_, p4)) => p = p4
          Err(msg) => return Err(msg)
        }
        lhs = Index(lhs, idx_expr)
        continue (lhs, p)
      }

      // -- LParen (function call) ---------------------------------------
      TokenKind::LParen => {
        let func_name = match lhs {
          Variable(n) => n
          _ => return Err("Expected function name before '('")
        }
        let (_, p2) = p.advance()
        p = p2
        let args_result = parse_arg_list(p, TokenKind::RParen)
        let (args, p3) = match args_result {
          Ok((a, pp)) => (a, pp)
          Err(msg) => return Err(msg)
        }
        p = p3
        lhs = Call(func_name, args)
        continue (lhs, p)
      }

      // -- Binary operators ---------------------------------------------
      _ => {
        let binop_opt = token_to_binop(tok.kind)
        let binop = match binop_opt {
          Some(op) => op
          None => break (lhs, p)
        }
        let (_, p2) = p.advance()
        p = p2
        let rhs_result = p.parse_expression(rbp)
        let (rhs, p3) = match rhs_result {
          Ok((e, pp)) => (e, pp)
          Err(msg) => return Err(msg)
        }
        p = p3
        lhs = BinOp(lhs, binop, rhs)
        continue (lhs, p)
      }
    }
  }

  Ok(result)
}

///|
/// Parse a primary expression or prefix operator.
fn Parser::parse_prefix(self : Parser) -> Result[(Expr, Parser), String] {
  let tok_opt = self.peek()
  let tok = match tok_opt {
    Some(t) => t
    None => return Err("Unexpected end of input in expression")
  }

  match tok.kind {
    TokenKind::Str(s) => {
      let (_, p) = self.advance()
      Ok((Literal(Str(s)), p))
    }
    TokenKind::Int(i) => {
      let (_, p) = self.advance()
      Ok((Literal(Int(i)), p))
    }
    TokenKind::Float(f) => {
      let (_, p) = self.advance()
      Ok((Literal(Float(f)), p))
    }
    TokenKind::Bool(b) => {
      let (_, p) = self.advance()
      Ok((Literal(Bool(b)), p))
    }
    TokenKind::Ident(name) => {
      let (_, p) = self.advance()
      Ok((Variable(name), p))
    }
    TokenKind::Not | TokenKind::Minus => {
      let op = match token_to_unary(tok.kind) {
        Some(o) => o
        None => return Err("Unknown unary operator")
      }
      let (_, p) = self.advance()
      let bp = match prefix_bp(tok.kind) {
        Some(b) => b
        None => 7
      }
      let operand_result = p.parse_expression(bp)
      let (operand, p2) = match operand_result {
        Ok((e, pp)) => (e, pp)
        Err(msg) => return Err(msg)
      }
      Ok((UnaryOp(op, operand), p2))
    }
    TokenKind::LParen => {
      let (_, p) = self.advance()
      let expr_result = p.parse_expression(0)
      let (expr, p2) = match expr_result {
        Ok((e, pp)) => (e, pp)
        Err(msg) => return Err(msg)
      }
      let expect_result = p2.expect(
        fn(t : Token) -> Bool { t.kind == TokenKind::RParen },
        "Expected ')'",
      )
      match expect_result {
        Ok((_, p3)) => Ok((expr, p3))
        Err(msg) => Err(msg)
      }
    }
    _ => Err(
      "Unexpected token in expression at line " +
      tok.line.to_string() +
      ", col " +
      tok.col.to_string(),
    )
  }
}

// ---------------------------------------------------------------------------
// Helper parsers
// ---------------------------------------------------------------------------

/// Parse a comma-separated argument list until *close* is encountered.
fn parse_arg_list(
  p : Parser,
  close : TokenKind
) -> Result[(Array[Expr], Parser), String] {
  let args : Array[Expr] = Array::new()
  let mut pp = p
  let close_label = token_kind_label(close)

  // Check for empty arg list.
  let first_opt = pp.peek()
  match first_opt {
    Some(tok) => {
      if tok.kind == close {
        let (_, p2) = pp.advance()
        return Ok((args, p2))
      }
    }
    None => return Err("Expected " + close_label + " but got EOF")
  }

  while true {
    let arg_result = pp.parse_expression(0)
    let (arg, p2) = match arg_result {
      Ok((a, pp2)) => (a, pp2)
      Err(msg) => return Err(msg)
    }
    pp = p2
    args.push(arg)

    let next_opt = pp.peek()
    match next_opt {
      Some(tok2) => {
        if tok2.kind == close {
          let (_, p3) = pp.advance()
          return Ok((args, p3))
        } else if tok2.kind == TokenKind::Comma {
          let (_, p3) = pp.advance()
          pp = p3
        } else {
          return Err("Expected ',' or " + close_label)
        }
      }
      None => return Err("Expected ',' or " + close_label + " but got EOF")
    }
  }
  // unreachable
  Err("unreachable")
}

/// Parse filter arguments: optional `(arg1, arg2, ...)` after filter name.
fn parse_filter_args(p : Parser) -> Result[(Array[Expr], Parser), String] {
  let tok_opt = p.peek()
  match tok_opt {
    Some(tok) => {
      if tok.kind == TokenKind::LParen {
        let (_, p2) = p.advance()
        parse_arg_list(p2, TokenKind::RParen)
      } else {
        Ok((Array::new(), p))
      }
    }
    None => Ok((Array::new(), p))
  }
}

// ---------------------------------------------------------------------------
// Top-level template parsing
// ---------------------------------------------------------------------------

///|
/// Parse the complete token stream into a list of template `Node`s.
pub fn Parser::parse_template(
  self : Parser
) -> Result[(Array[Node], Parser), String] {
  // parse_nodes with an empty stop set (never stops except at EOF).
  let stop : Array[TokenKind] = Array::new()
  let result = self.parse_nodes(stop)
  match result {
    Ok((nodes, p)) => Ok((nodes, p))
    Err(msg) => Err(msg)
  }
}

// ---------------------------------------------------------------------------
// Generic body parser — parses nodes until a stop keyword
// ---------------------------------------------------------------------------

///|
/// Parse nodes until `OpenTag` followed by one of *stop_kinds* (or EOF).
///
/// When a stop keyword is encountered, the `OpenTag` and keyword are NOT
/// consumed — they remain for the caller to handle.
fn Parser::parse_nodes(
  self : Parser,
  stop_kinds : Array[TokenKind]
) -> Result[(Array[Node], Parser), String] {
  let nodes : Array[Node] = Array::new()
  let mut p = self

  while true {
    let tok_opt = p.peek()
    let tok = match tok_opt {
      Some(t) => t
      None => break
    }

    match tok.kind {
      TokenKind::Eof => break

      // -- Plain text ------------------------------------------------------
      TokenKind::Text(content) => {
        let (_, p2) = p.advance()
        p = p2
        if content != "" {
          nodes.push(Text(content))
        }
      }

      // -- Variable output  {{ expr }} ------------------------------------
      TokenKind::OpenVar => {
        let (_, p2) = p.advance()
        p = p2
        let expr_result = p.parse_expression(0)
        let (expr, p3) = match expr_result {
          Ok((e, pp)) => (e, pp)
          Err(msg) => return Err(msg)
        }
        p = p3
        let expect_result = p.expect(
          fn(t : Token) -> Bool { t.kind == TokenKind::CloseVar },
          "Expected '}}'",
        )
        match expect_result {
          Ok((_, p4)) => p = p4
          Err(msg) => return Err(msg)
        }
        nodes.push(Output(expr))
      }

      // -- Block tag  {% ... %} — dispatch on keyword ---------------------
      TokenKind::OpenTag => {
        let (_, p2) = p.advance()
        p = p2

        // Peek at the keyword.
        let keyword_opt = p.peek()
        let keyword_tok = match keyword_opt {
          Some(t) => t
          None => return Err("Expected keyword after '{%', got EOF")
        }

        // Check if this is a stop keyword — if so, back out.
        let is_stop = is_stop_keyword(keyword_tok.kind, stop_kinds)
        if is_stop {
          // Don't advance — let the caller handle it.
          // But we already consumed OpenTag.  Put it back conceptually
          // by returning the parser state BEFORE OpenTag was consumed.
          // Simple fix: peek_at(-1) doesn't work.  Instead, we return
          // with the parser positioned at the keyword (OpenTag consumed).
          // The caller (parse_if_block) expects to see the keyword.
          break
        }

        // Not a stop keyword — dispatch.
        let dispatch_result = dispatch_block_tag(p, keyword_tok)
        match dispatch_result {
          Ok((opt_node, p3)) => {
            p = p3
            match opt_node {
              Some(node) => nodes.push(node)
              None => () // skipped block
            }
          }
          Err(msg) => return Err(msg)
        }
      }

      // -- Comment, close tags, etc. — skip silently -----------------------
      TokenKind::OpenComment | TokenKind::CloseComment |
      TokenKind::CloseVar | TokenKind::CloseTag => {
        let (_, p2) = p.advance()
        p = p2
      }

      // -- Error tokens — propagate ----------------------------------------
      TokenKind::Error(msg) => {
        let (_, p2) = p.advance()
        p = p2
        return Err("Lexer error: " + msg)
      }

      // -- Unexpected token ------------------------------------------------
      _ => {
        return Err(
          "Unexpected token in template at line " +
          tok.line.to_string() +
          ", col " +
          tok.col.to_string(),
        )
      }
    }
  }

  Ok((nodes, p))
}

// ---------------------------------------------------------------------------
// Block tag dispatch
// ---------------------------------------------------------------------------

/// Check if *kind* is in the stop list.
fn is_stop_keyword(kind : TokenKind, stop_kinds : Array[TokenKind]) -> Bool {
  for k in stop_kinds {
    if kind == k {
      return true
    }
  }
  false
}

/// Dispatch a block tag based on its keyword.
/// Returns `(Option[Node], Parser)` — `None` means the block was skipped.
fn dispatch_block_tag(
  p : Parser,
  keyword_tok : Token
) -> Result[(Option[Node], Parser), String] {
  match keyword_tok.kind {
    // -- if block ---------------------------------------------------------
    TokenKind::If => {
      let parsed = parse_if_block(p)
      match parsed {
        Ok((if_node, p2)) => Ok((Some(if_node), p2))
        Err(msg) => Err(msg)
      }
    }

    // -- Elif / Else / Endif appearing outside if block — error ----------
    TokenKind::Elif => Err("Unexpected 'elif' outside of if block")
    TokenKind::Else => Err("Unexpected 'else' outside of if block")
    TokenKind::Endif => Err("Unexpected 'endif' outside of if block")
    TokenKind::Endfor => Err("Unexpected 'endfor' outside of for block")
    TokenKind::Endblock => Err("Unexpected 'endblock' outside of block")

    // -- For now, skip other block tags ----------------------------------
    _ => {
      let p2 = skip_until_close_tag(p)
      match p2 {
        Ok(pp) => Ok((None, pp))
        Err(msg) => Err(msg)
      }
    }
  }
}

// ---------------------------------------------------------------------------
// If-block parser
// ---------------------------------------------------------------------------

/// Parse a full `{% if cond %} ... {% elif cond %} ... {% else %} ... {% endif %}`.
///
/// Caller has already consumed `OpenTag`.  We consume `If` and everything
/// through `Endif` + `CloseTag`.
fn parse_if_block(p : Parser) -> Result[(Node, Parser), String] {
  // 1. Consume 'if' keyword.
  let (if_tok, p1) = p.advance()
  let _ = if_tok

  // 2. Parse condition expression.
  let cond_result = p1.parse_expression(0)
  let (condition, p2) = match cond_result {
    Ok((e, pp)) => (e, pp)
    Err(msg) => return Err(msg)
  }

  // 3. Expect CloseTag.
  let expect_result = p2.expect(
    fn(t : Token) -> Bool { t.kind == TokenKind::CloseTag },
    "Expected '%}' after 'if' condition",
  )
  let p3 = match expect_result {
    Ok((_, pp)) => pp
    Err(msg) => return Err(msg)
  }

  // 4. Parse then-body until elif / else / endif.
  let stop_kinds : Array[TokenKind] = [
    TokenKind::Elif,
    TokenKind::Else,
    TokenKind::Endif,
  ]
  let body_result = p3.parse_nodes(stop_kinds)
  let (then_body, p4) = match body_result {
    Ok((ns, pp)) => (ns, pp)
    Err(msg) => return Err(msg)
  }

  // 5. Parse elif branches and optional else.
  let elifs : Array[ElifBranch] = Array::new()
  let else_body : Array[Node] = Array::new()
  let chain_result = parse_elif_else_chain(p4, elifs, else_body)
  let (elif_branches, else_nodes, p5) = match chain_result {
    Ok((eb, en, pp)) => (eb, en, pp)
    Err(msg) => return Err(msg)
  }

  let p_final = p5

  // 6. Expect Endif (the stop keyword was not consumed by parse_nodes).
  let end_tag_opt = p_final.peek()
  match end_tag_opt {
    Some(t) => {
      if t.kind == TokenKind::OpenTag {
        // Consume OpenTag.
        let (_, p_ot) = p_final.advance()
        let endif_opt = p_ot.peek()
        match endif_opt {
          Some(et) => {
            if et.kind == TokenKind::Endif {
              let (_, p_if) = p_ot.advance()
              // Expect CloseTag.
              let close_result = p_if.expect(
                fn(ct : Token) -> Bool { ct.kind == TokenKind::CloseTag },
                "Expected '%}' after 'endif'",
              )
              match close_result {
                Ok((_, p_ok)) => {
                  let if_node = Node::If(
                    condition, then_body, elif_branches, else_nodes,
                  )
                  return Ok((if_node, p_ok))
                }
                Err(msg) => return Err(msg)
              }
            } else {
              return Err("Expected 'endif' to close if block")
            }
          }
          None => return Err("Expected 'endif', got EOF")
        }
      } else {
        return Err("Expected '{% endif %}' to close if block")
      }
    }
    None => return Err("Expected '{% endif %}', got EOF")
  }
}

/// Parse the elif / else chain after the then-body.
///
/// Returns `(elif_branches, else_body, parser)`.
fn parse_elif_else_chain(
  p : Parser,
  elifs : Array[ElifBranch],
  else_nodes : Array[Node]
) -> Result[(Array[ElifBranch], Array[Node], Parser), String] {
  let mut pp = p
  let elif_branches = elifs
  let mut else_body = else_nodes

  while true {
    let tok_opt = pp.peek()
    let tok = match tok_opt {
      Some(t) => t
      None => break
    }

    match tok.kind {
      // Must be OpenTag (since parse_nodes stopped here).
      TokenKind::OpenTag => {
        let (_, p2) = pp.advance()
        pp = p2

        // Check the keyword.
        let kw_opt = pp.peek()
        let kw = match kw_opt {
          Some(t) => t
          None => return Err("Expected keyword after '{%', got EOF")
        }

        match kw.kind {
          // -- elif ----------------------------------------------------
          TokenKind::Elif => {
            let (_, p3) = pp.advance()
            pp = p3
            // Parse elif condition.
            let cond_result = pp.parse_expression(0)
            let (elif_cond, p4) = match cond_result {
              Ok((e, ppp)) => (e, ppp)
              Err(msg) => return Err(msg)
            }
            pp = p4
            // Expect CloseTag.
            let close_result = pp.expect(
              fn(t : Token) -> Bool { t.kind == TokenKind::CloseTag },
              "Expected '%}' after 'elif' condition",
            )
            pp = match close_result {
              Ok((_, ppp)) => ppp
              Err(msg) => return Err(msg)
            }
            // Parse elif body until elif / else / endif.
            let stop_kinds : Array[TokenKind] = [
              TokenKind::Elif,
              TokenKind::Else,
              TokenKind::Endif,
            ]
            let body_result = pp.parse_nodes(stop_kinds)
            let (elif_body, p5) = match body_result {
              Ok((ns, ppp)) => (ns, ppp)
              Err(msg) => return Err(msg)
            }
            pp = p5
            let branch = ElifBranch::{
              condition: Option::Some(elif_cond),
              body: elif_body,
            }
            elif_branches.push(branch)
            // Loop: check for more elif / else / endif.
          }

          // -- else ----------------------------------------------------
          TokenKind::Else => {
            let (_, p3) = pp.advance()
            pp = p3
            // Expect CloseTag.
            let close_result = pp.expect(
              fn(t : Token) -> Bool { t.kind == TokenKind::CloseTag },
              "Expected '%}' after 'else'",
            )
            pp = match close_result {
              Ok((_, ppp)) => ppp
              Err(msg) => return Err(msg)
            }
            // Parse else body until endif.
            let stop_kinds : Array[TokenKind] = [
              TokenKind::Endif,
            ]
            let body_result = pp.parse_nodes(stop_kinds)
            let (else_nodes_parsed, p5) = match body_result {
              Ok((ns, ppp)) => (ns, ppp)
              Err(msg) => return Err(msg)
            }
            pp = p5
            else_body = else_nodes_parsed
            break
          }

          // -- endif ---------------------------------------------------
          TokenKind::Endif => break

          // -- Unexpected keyword --------------------------------------
          _ => return Err("Expected 'elif', 'else', or 'endif'")
        }
      }
      _ => break
    }
  }

  Ok((elif_branches, else_body, pp))
}

/// Skip tokens until `CloseTag` (`%}`) is encountered.
fn skip_until_close_tag(p : Parser) -> Result[Parser, String] {
  let mut pp = p
  while true {
    let tok_opt = pp.peek()
    let tok = match tok_opt {
      Some(t) => t
      None => return Err("Unclosed block tag — expected '%}'")
    }

    match tok.kind {
      TokenKind::CloseTag => {
        let (_, p2) = pp.advance()
        return Ok(p2)
      }
      TokenKind::Eof => return Err("Unclosed block tag — expected '%}' before end of file")
      _ => {
        let (_, p2) = pp.advance()
        pp = p2
      }
    }
  }
  Err("unreachable")
}
