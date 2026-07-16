// ---------------------------------------------------------------------------
// MoonTera — Lexer (词法分析器)
//
// Converts a template source string into a flat stream of Tokens.
// Each token carries its source position (line, column) for error reporting.
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Token kinds
// ---------------------------------------------------------------------------

pub enum TokenKind {
  Text(String)
  // Delimiters
  OpenVar
  CloseVar
  OpenTag
  CloseTag
  OpenComment
  CloseComment
  // Keywords
  If
  Elif
  Else
  Endif
  For
  In
  Endfor
  Block
  Endblock
  Extends
  Macro
  Endmacro
  Include
  And
  Or
  Not
  // Literals & identifiers
  Ident(String)
  Str(String)
  Int(String)    // raw integer string, parsed later
  Float(String)  // raw float string, parsed later
  Bool(Bool)
  // Arithmetic
  Plus
  Minus
  Star
  Slash
  Percent
  // Comparison
  Eq
  NotEq
  Lt
  Gt
  LtEq
  GtEq
  // Punctuation
  Pipe
  Colon
  Comma
  Dot
  LParen
  RParen
  Assign
  // Special
  Eof
  Error(String)
}

// ---------------------------------------------------------------------------
// Token with source position
// ---------------------------------------------------------------------------

pub struct Token {
  kind : TokenKind
  line : Int
  col : Int
}

// ---------------------------------------------------------------------------
// Eq for TokenKind — enables == and != on tokens
// ---------------------------------------------------------------------------

impl Eq for TokenKind with equal(a, b) {
  match (a, b) {
    (TokenKind::Text(x), TokenKind::Text(y)) => x == y
    (TokenKind::Ident(x), TokenKind::Ident(y)) => x == y
    (TokenKind::Str(x), TokenKind::Str(y)) => x == y
    (TokenKind::Int(x), TokenKind::Int(y)) => x == y
    (TokenKind::Float(x), TokenKind::Float(y)) => x == y
    (TokenKind::Bool(x), TokenKind::Bool(y)) => x == y
    (TokenKind::Error(x), TokenKind::Error(y)) => x == y
    (TokenKind::OpenVar, TokenKind::OpenVar) => true
    (TokenKind::CloseVar, TokenKind::CloseVar) => true
    (TokenKind::OpenTag, TokenKind::OpenTag) => true
    (TokenKind::CloseTag, TokenKind::CloseTag) => true
    (TokenKind::OpenComment, TokenKind::OpenComment) => true
    (TokenKind::CloseComment, TokenKind::CloseComment) => true
    (TokenKind::If, TokenKind::If) => true
    (TokenKind::Elif, TokenKind::Elif) => true
    (TokenKind::Else, TokenKind::Else) => true
    (TokenKind::Endif, TokenKind::Endif) => true
    (TokenKind::For, TokenKind::For) => true
    (TokenKind::In, TokenKind::In) => true
    (TokenKind::Endfor, TokenKind::Endfor) => true
    (TokenKind::Block, TokenKind::Block) => true
    (TokenKind::Endblock, TokenKind::Endblock) => true
    (TokenKind::Extends, TokenKind::Extends) => true
    (TokenKind::Macro, TokenKind::Macro) => true
    (TokenKind::Endmacro, TokenKind::Endmacro) => true
    (TokenKind::Include, TokenKind::Include) => true
    (TokenKind::And, TokenKind::And) => true
    (TokenKind::Or, TokenKind::Or) => true
    (TokenKind::Not, TokenKind::Not) => true
    (TokenKind::Plus, TokenKind::Plus) => true
    (TokenKind::Minus, TokenKind::Minus) => true
    (TokenKind::Star, TokenKind::Star) => true
    (TokenKind::Slash, TokenKind::Slash) => true
    (TokenKind::Percent, TokenKind::Percent) => true
    (TokenKind::Eq, TokenKind::Eq) => true
    (TokenKind::NotEq, TokenKind::NotEq) => true
    (TokenKind::Lt, TokenKind::Lt) => true
    (TokenKind::Gt, TokenKind::Gt) => true
    (TokenKind::LtEq, TokenKind::LtEq) => true
    (TokenKind::GtEq, TokenKind::GtEq) => true
    (TokenKind::Pipe, TokenKind::Pipe) => true
    (TokenKind::Colon, TokenKind::Colon) => true
    (TokenKind::Comma, TokenKind::Comma) => true
    (TokenKind::Dot, TokenKind::Dot) => true
    (TokenKind::LParen, TokenKind::LParen) => true
    (TokenKind::RParen, TokenKind::RParen) => true
    (TokenKind::Assign, TokenKind::Assign) => true
    (TokenKind::Eof, TokenKind::Eof) => true
    _ => false
  }
}

// ---------------------------------------------------------------------------
// Lexer state machine
// ---------------------------------------------------------------------------

enum LexerState {
  Text
  Variable
  Tag
}

pub struct Lexer {
  input : String
  mut pos : Int
  mut line : Int
  mut col : Int
  mut state : LexerState
}

// ---------------------------------------------------------------------------
// Constructor
// ---------------------------------------------------------------------------

pub fn Lexer::new(input : String) -> Lexer {
  {
    input,
    pos: 0,
    line: 1,
    col: 1,
    state: LexerState::Text,
  }
}

// ===========================================================================
// Public API
// ===========================================================================

pub fn Lexer::tokenize(self : Lexer) -> Array[Token] {
  let tokens = []
  let mut lex = self

  while lex.pos < lex.input.length() {
    match lex.state {
      LexerState::Text => lex = lex.tokenize_text(tokens)
      LexerState::Variable => lex = lex.tokenize_variable(tokens)
      LexerState::Tag => lex = lex.tokenize_tag(tokens)
    }
  }

  // If we exited the loop while still inside a tag, emit an error.
  match lex.state {
    LexerState::Text => ()
    _ => tokens.push(
      Token::{ kind: TokenKind::Error("Unclosed tag at end of input"), line: lex.line, col: lex.col },
    )
  }

  tokens.push(Token::{ kind: TokenKind::Eof, line: lex.line, col: lex.col })
  tokens
}

// ===========================================================================
// State handlers
// ===========================================================================

fn Lexer::tokenize_text(self : Lexer, tokens : Array[Token]) -> Lexer {
  let mut lex = self
  if lex.starts_with("{{") {
    lex = lex.advance(2)
    lex.state = LexerState::Variable
    tokens.push(Token::{ kind: TokenKind::OpenVar, line: lex.line, col: lex.col - 2 })
  } else if lex.starts_with("{%") {
    lex = lex.advance(2)
    lex.state = LexerState::Tag
    tokens.push(Token::{ kind: TokenKind::OpenTag, line: lex.line, col: lex.col - 2 })
  } else if lex.starts_with("{#") {
    lex = lex.skip_comment()
  } else {
    let (next_lex, token) = lex.read_text()
    lex = next_lex
    tokens.push(token)
  }
  lex
}

fn Lexer::tokenize_variable(self : Lexer, tokens : Array[Token]) -> Lexer {
  let mut lex = self
  lex = lex.skip_whitespace()
  if lex.pos >= lex.input.length() {
    tokens.push(
      Token::{ kind: TokenKind::Error("Unclosed tag — expected }}"), line: lex.line, col: lex.col },
    )
  } else if lex.starts_with("}}") {
    lex = lex.advance(2)
    lex.state = LexerState::Text
    tokens.push(Token::{ kind: TokenKind::CloseVar, line: lex.line, col: lex.col - 2 })
  } else {
    let (next_lex, token) = lex.read_expr_token()
    lex = next_lex
    tokens.push(token)
  }
  lex
}

fn Lexer::tokenize_tag(self : Lexer, tokens : Array[Token]) -> Lexer {
  let mut lex = self
  lex = lex.skip_whitespace()
  if lex.pos >= lex.input.length() {
    tokens.push(
      Token::{ kind: TokenKind::Error("Unclosed tag — expected %}"), line: lex.line, col: lex.col },
    )
  } else if lex.starts_with("%}") {
    lex = lex.advance(2)
    lex.state = LexerState::Text
    tokens.push(Token::{ kind: TokenKind::CloseTag, line: lex.line, col: lex.col - 2 })
  } else {
    let (next_lex, token) = lex.read_expr_token()
    lex = next_lex
    tokens.push(token)
  }
  lex
}

// ===========================================================================
// Character helpers — String indexing returns UInt16 (UTF-16 code unit)
// ===========================================================================

/// Get the code unit at the current position.
fn Lexer::code_unit(self : Lexer) -> UInt16 {
  self.input[self.pos]
}

/// Get the code unit at a specific index.
fn Lexer::code_unit_at(self : Lexer, idx : Int) -> UInt16 {
  self.input[idx]
}

/// Check if a code unit is alphabetic (a-z, A-Z).
fn is_alpha(cu : UInt16) -> Bool {
  (cu >= 'A' && cu <= 'Z') || (cu >= 'a' && cu <= 'z')
}

/// Check if a code unit is a digit (0-9).
fn is_digit(cu : UInt16) -> Bool {
  cu >= '0' && cu <= '9'
}

/// Check if a code unit is alphanumeric or underscore.
fn is_ident_char(cu : UInt16) -> Bool {
  (cu >= 'A' && cu <= 'Z') || (cu >= 'a' && cu <= 'z') || (cu >= '0' && cu <= '9') || cu == '_'
}

/// Check if a code unit is whitespace (inside tags).
fn is_tag_space(cu : UInt16) -> Bool {
  cu == ' ' || cu == '\t' || cu == '\r'
}

// ===========================================================================
// Keyword lookup
// ===========================================================================

fn lookup_keyword(ident : String) -> TokenKind {
  if ident == "if" {
    TokenKind::If
  } else if ident == "elif" {
    TokenKind::Elif
  } else if ident == "else" {
    TokenKind::Else
  } else if ident == "endif" {
    TokenKind::Endif
  } else if ident == "for" {
    TokenKind::For
  } else if ident == "in" {
    TokenKind::In
  } else if ident == "endfor" {
    TokenKind::Endfor
  } else if ident == "block" {
    TokenKind::Block
  } else if ident == "endblock" {
    TokenKind::Endblock
  } else if ident == "extends" {
    TokenKind::Extends
  } else if ident == "macro" {
    TokenKind::Macro
  } else if ident == "endmacro" {
    TokenKind::Endmacro
  } else if ident == "include" {
    TokenKind::Include
  } else if ident == "and" {
    TokenKind::And
  } else if ident == "or" {
    TokenKind::Or
  } else if ident == "not" {
    TokenKind::Not
  } else if ident == "true" {
    TokenKind::Bool(true)
  } else if ident == "false" {
    TokenKind::Bool(false)
  } else {
    TokenKind::Ident(ident)
  }
}

// ===========================================================================
// Cursor inspection
// ===========================================================================

fn Lexer::starts_with(self : Lexer, s : String) -> Bool {
  if self.pos + s.length() > self.input.length() {
    return false
  }
  for i = 0; i < s.length(); i = i + 1 {
    if self.input[self.pos + i] != s[i] {
      return false
    }
  }
  true
}

// ===========================================================================
// Cursor movement — returns updated Lexer
// ===========================================================================

fn Lexer::advance(self : Lexer, n : Int) -> Lexer {
  let lex = self
  for i = 0; i < n; i = i + 1 {
    if lex.pos >= lex.input.length() {
      break
    }
    if lex.input[lex.pos] == '\n' {
      lex.line = lex.line + 1
      lex.col = 1
    } else {
      lex.col = lex.col + 1
    }
    lex.pos = lex.pos + 1
  }
  lex
}

// ===========================================================================
// Whitespace (inside tags)
// ===========================================================================

fn Lexer::skip_whitespace(self : Lexer) -> Lexer {
  let mut lex = self
  while lex.pos < lex.input.length() {
    let cu = lex.code_unit()
    if is_tag_space(cu) {
      lex = lex.advance(1)
    } else {
      break
    }
  }
  lex
}

// ===========================================================================
// Comment
// ===========================================================================

fn Lexer::skip_comment(self : Lexer) -> Lexer {
  let mut lex = self.advance(2)
  while lex.pos < lex.input.length() {
    if lex.starts_with("#}") {
      lex = lex.advance(2)
      return lex
    }
    lex = lex.advance(1)
  }
  lex
}

// ===========================================================================
// Text accumulation
// ===========================================================================

fn Lexer::read_text(self : Lexer) -> (Lexer, Token) {
  let start_line = self.line
  let start_col = self.col
  let mut lex = self
  let mut s = ""
  while lex.pos < lex.input.length() {
    if lex.starts_with("{{") || lex.starts_with("{%") || lex.starts_with("{#") {
      break
    }
    let cu = lex.code_unit()
    s = s + Int::unsafe_to_char(cu.to_int()).to_string()
    lex = lex.advance(1)
  }
  let token = Token::{ kind: TokenKind::Text(s), line: start_line, col: start_col }
  (lex, token)
}

// ===========================================================================
// Expression token
// ===========================================================================

fn Lexer::read_expr_token(self : Lexer) -> (Lexer, Token) {
  let cu = self.code_unit()
  if is_alpha(cu) || cu == '_' {
    return self.read_ident_or_keyword()
  }
  if cu == '"' || cu == '\'' {
    return self.read_string()
  }
  if is_digit(cu) {
    return self.read_number()
  }
  self.read_operator_or_punctuation()
}

// ===========================================================================
// Identifier / keyword
// ===========================================================================

fn Lexer::read_ident_or_keyword(self : Lexer) -> (Lexer, Token) {
  let start_line = self.line
  let start_col = self.col
  let mut lex = self
  let mut s = ""
  while lex.pos < lex.input.length() {
    let cu = lex.code_unit()
    if is_ident_char(cu) {
      s = s + Int::unsafe_to_char(cu.to_int()).to_string()
      lex = lex.advance(1)
    } else {
      break
    }
  }
  let kind = lookup_keyword(s)
  let token = Token::{ kind, line: start_line, col: start_col }
  (lex, token)
}

// ===========================================================================
// String literal
// ===========================================================================

fn Lexer::read_string(self : Lexer) -> (Lexer, Token) {
  let start_line = self.line
  let start_col = self.col
  let quote_cu = self.code_unit()
  let mut lex = self.advance(1)
  let mut s = ""
  while lex.pos < lex.input.length() {
    let cu = lex.code_unit()
    if cu == quote_cu {
      lex = lex.advance(1)
      let token = Token::{ kind: TokenKind::Str(s), line: start_line, col: start_col }
      return (lex, token)
    }
    if cu == '\\' {
      lex = lex.advance(1)
      if lex.pos < lex.input.length() {
        let esc_cu = lex.code_unit()
        if esc_cu == 'n' {
          s = s + "\n"
        } else if esc_cu == 't' {
          s = s + "\t"
        } else if esc_cu == 'r' {
          s = s + "\r"
        } else if esc_cu == '\\' {
          s = s + "\\"
        } else if esc_cu == '"' {
          s = s + "\""
        } else if esc_cu == '\'' {
          s = s + "'"
        } else {
          s = s + "\\"
          s = s + Int::unsafe_to_char(esc_cu.to_int()).to_string()
        }
        lex = lex.advance(1)
      }
    } else {
      s = s + Int::unsafe_to_char(cu.to_int()).to_string()
      lex = lex.advance(1)
    }
  }
  let token = Token::{ kind: TokenKind::Error("Unclosed string literal"), line: start_line, col: start_col }
  (lex, token)
}

// ===========================================================================
// Number literal — stored as raw string, parsed later
// ===========================================================================

fn Lexer::read_number(self : Lexer) -> (Lexer, Token) {
  let start_line = self.line
  let start_col = self.col
  let mut lex = self
  let mut s = ""
  let mut is_float = false
  while lex.pos < lex.input.length() {
    let cu = lex.code_unit()
    if is_digit(cu) {
      s = s + Int::unsafe_to_char(cu.to_int()).to_string()
      lex = lex.advance(1)
    } else if cu == '.' && !is_float {
      // A dot is a decimal point only if followed by a digit.
      if lex.pos + 1 < lex.input.length() && is_digit(lex.code_unit_at(lex.pos + 1)) {
        is_float = true
        s = s + "."
        lex = lex.advance(1)
      } else {
        break
      }
    } else {
      break
    }
  }
  let kind = if is_float {
    TokenKind::Float(s)
  } else {
    TokenKind::Int(s)
  }
  let token = Token::{ kind, line: start_line, col: start_col }
  (lex, token)
}

// ===========================================================================
// Operators & punctuation
// ===========================================================================

fn Lexer::read_operator_or_punctuation(self : Lexer) -> (Lexer, Token) {
  let line = self.line
  let col = self.col

  // Two-character operators
  if self.starts_with("==") {
    let lex = self.advance(2)
    let token = Token::{ kind: TokenKind::Eq, line, col }
    return (lex, token)
  }
  if self.starts_with("!=") {
    let lex = self.advance(2)
    let token = Token::{ kind: TokenKind::NotEq, line, col }
    return (lex, token)
  }
  if self.starts_with("<=") {
    let lex = self.advance(2)
    let token = Token::{ kind: TokenKind::LtEq, line, col }
    return (lex, token)
  }
  if self.starts_with(">=") {
    let lex = self.advance(2)
    let token = Token::{ kind: TokenKind::GtEq, line, col }
    return (lex, token)
  }

  // Single-character tokens — read char first, then advance
  let cu = self.code_unit()
  let lex = self.advance(1)
  let kind = if cu == '+' {
    TokenKind::Plus
  } else if cu == '-' {
    TokenKind::Minus
  } else if cu == '*' {
    TokenKind::Star
  } else if cu == '/' {
    TokenKind::Slash
  } else if cu == '%' {
    TokenKind::Percent
  } else if cu == '|' {
    TokenKind::Pipe
  } else if cu == ':' {
    TokenKind::Colon
  } else if cu == ',' {
    TokenKind::Comma
  } else if cu == '.' {
    TokenKind::Dot
  } else if cu == '(' {
    TokenKind::LParen
  } else if cu == ')' {
    TokenKind::RParen
  } else if cu == '=' {
    TokenKind::Assign
  } else if cu == '<' {
    TokenKind::Lt
  } else if cu == '>' {
    TokenKind::Gt
  } else if cu == '!' {
    TokenKind::Not
  } else {
    TokenKind::Error("Unexpected character: " + Int::unsafe_to_char(cu.to_int()).to_string())
  }
  let token = Token::{ kind, line, col }
  (lex, token)
}
