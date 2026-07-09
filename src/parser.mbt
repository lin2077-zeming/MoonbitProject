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
// Top-level parse entry point
// ---------------------------------------------------------------------------

///|
/// Parse the complete token stream into a template AST.
///
/// Currently returns an empty node list — the full parser will be
/// implemented in subsequent changes.
pub fn Parser::parse_template(self : Parser) -> Result[(Array[Node], Parser), String] {
  let nodes : Array[Node] = Array::new()
  Ok((nodes, self))
}
