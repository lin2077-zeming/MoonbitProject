// Copyright (c) 2024 LinZeming
// Released under the MIT License
//
// Lexer — converts a template source string into a stream of `Token`s.
//
// Architecture
// ------------
// The lexer operates as a state machine with four modes:
//
//   Text    — scanning plain text until a tag delimiter is found
//   Expr    — inside {{ ... }} variable/expression blocks
//   Block   — inside {% ... %} statement blocks
//   Comment — inside {# ... #} comment blocks (tokens are discarded)
//
// On encountering a tag delimiter the lexer emits the accumulated Text
// token (if any), emits the opening delimiter token, and switches into
// the corresponding inner mode.  Inner-mode tokenisation is identical
// for Expr and Block except for two things:
//   1. The closing delimiter is }} for Expr and %} for Block.
//   2. Block mode recognises template keywords (if, for, block, …)
//      that would be plain identifiers in Expr mode.

// ---------------------------------------------------------------------------
// Token types
// ---------------------------------------------------------------------------

///|
/// Every kind of token the lexer can produce.
pub(all) enum TokenKind {
  // -- Plain text ------------------------------------------------------------
  Text(String) // raw template text outside tags

  // -- Tag delimiters --------------------------------------------------------
  OpenVar // {{
  CloseVar // }}
  OpenTag // {%
  CloseTag // %}
  OpenComment // {#  (produced but filtered by tokenize)
  CloseComment // #}  (produced but filtered by tokenize)

  // -- Block-level keywords --------------------------------------------------
  If // if
  Elif // elif
  Else // else
  Endif // endif
  For // for
  In // in
  Endfor // endfor
  Block // block
  Endblock // endblock
  Extends // extends
  Macro // macro
  Endmacro // endmacro
  Include // include

  // -- Literals --------------------------------------------------------------
  Ident(String) // user-defined identifier
  Str(String) // string literal  "…" or '…'
  Int(Int64) // integer literal
  Float(Double) // floating-point literal
  Bool(Bool) // true / false

  // -- Operators -------------------------------------------------------------
  Plus // +
  Minus // -
  Star // *
  Slash // /
  Percent // %
  Eq // ==
  NotEq // !=
  Lt // <
  Gt // >
  LtEq // <=
  GtEq // >=
  And // and
  Or // or
  Not // not
  Pipe // |
  Colon // :
  Comma // ,
  Dot // .
  LParen // (
  RParen // )
  LBracket // [
  RBracket // ]
  Assign // =
  Tilde // ~   (string concatenation operator)

  // -- Special ---------------------------------------------------------------
  Eof // end of input
  Error(String) // recoverable lexical error
} derive(Eq, Debug)

///|
/// A token together with its source position (1-based line / column).
pub(all) struct Token {
  kind : TokenKind
  line : Int
  col : Int
} derive(Debug)

// ---------------------------------------------------------------------------
// Lexer state machine
// ---------------------------------------------------------------------------

///|
/// Internal lexer mode.
priv enum Mode {
  Text
  Expr
  Block
  Comment
}

///|
/// Internal lexer state passed explicitly between methods.
///
/// Each method returns a `(result, Lexer)` pair so the caller always has the
/// latest state without needing mutable references.  The `tokenize` entry
/// point drives the loop.
priv struct Lexer {
  input : String
  pos : Int // current character index
  line : Int // 1-based line of current position
  col : Int // 1-based column of current position
  mode : Mode
  text_start : Int // start index of accumulated text (or 0)
  text_line : Int // line where current text buffer began
  text_col : Int // column where current text buffer began
  has_text : Bool // true when text_start is valid
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

///|
/// Tokenise *input* into a flat `Array[Token]`.
///
/// Comment blocks (`{# … #}`) are silently consumed — they never appear in
/// the returned token stream.  Recoverable errors (e.g. unclosed string or
/// unknown character) are represented as `TokenKind::Error` tokens so the
/// parser can report multiple problems in a single pass.
pub fn tokenize(input : String) -> Result[Array[Token], String] {
  let tokens : Array[Token] = Array::new()
  let mut lex = Lexer::new(input)
  while true {
    let (tok, next) = lex.next_token()
    lex = next

    // Filter out comment-related tokens.
    if tok.kind == TokenKind::OpenComment || tok.kind == TokenKind::CloseComment {
      continue
    }

    let is_eof = tok.kind == TokenKind::Eof
    tokens.push(tok)
    if is_eof {
      break
    }
  }
  Ok(tokens)
}

// ---------------------------------------------------------------------------
// Constructors
// ---------------------------------------------------------------------------

///|
fn Lexer::new(input : String) -> Lexer {
  {
    input,
    pos: 0,
    line: 1,
    col: 1,
    mode: Mode::Text,
    text_start: 0,
    text_line: 1,
    text_col: 1,
    has_text: false,
  }
}

///|
fn make_token(kind : TokenKind, line : Int, col : Int) -> Token {
  { kind, line, col }
}

///|
fn make_error(msg : String, line : Int, col : Int) -> Token {
  { kind: TokenKind::Error(msg), line, col }
}

// ---------------------------------------------------------------------------
// Character helpers — string indexing returns UInt16
// ---------------------------------------------------------------------------

///|
/// Character literal helper: convert a `Char` to the `UInt16` that
/// `String` indexing produces.
fn char_code(ch : Char) -> Int {
  ch.to_int()
}

///|
/// Peek at the code-unit *offset* positions ahead without advancing.
/// Returns `None` past EOF.
fn Lexer::peek(self : Lexer, offset : Int) -> Int? {
  let idx = self.pos + offset
  if idx >= 0 && idx < self.input.length() {
    Some(self.input[idx].to_int())
  } else {
    None
  }
}

///|
/// True when the literal *s* appears at the current position.
fn Lexer::peek_str(self : Lexer, s : String) -> Bool {
  let end = self.pos + s.length()
  if end > self.input.length() {
    return false
  }
  let mut i = 0
  while i < s.length() {
    if self.input[self.pos + i].to_int() != s[i].to_int() {
      return false
    }
    i = i + 1
  }
  true
}

///|
/// Advance *n* characters, updating line / column.
fn Lexer::advance(self : Lexer, n : Int) -> Lexer {
  let mut line = self.line
  let mut col = self.col
  let end = self.pos + n
  let mut i = self.pos
  while i < end && i < self.input.length() {
    let ch = self.input[i]
    if ch.to_int() == char_code('\n') {
      line = line + 1
      col = 1
    } else {
      col = col + 1
    }
    i = i + 1
  }
  let new_pos = if self.pos + n <= self.input.length() {
    self.pos + n
  } else {
    self.input.length()
  }
  { ..self, pos: new_pos, line, col }
}

///|
/// Advance a single character.
fn Lexer::advance_one(self : Lexer) -> Lexer {
  self.advance(1)
}

///|
/// Skip whitespace characters; return updated lexer.
fn Lexer::skip_whitespace(self : Lexer) -> Lexer {
  let mut lex = self
  let input_len = lex.input.length()
  let space = char_code(' ')
  let tab = char_code('\t')
  let cr = char_code('\r')
  let nl = char_code('\n')
  while lex.pos < input_len {
    let ch = lex.input[lex.pos].to_int()
    if ch == space || ch == tab || ch == cr || ch == nl {
      lex = lex.advance_one()
    } else {
      break
    }
  }
  lex
}

///|
/// Test whether a code-unit can start an identifier (or keyword).
fn is_ident_start(ch : Int) -> Bool {
  (ch >= char_code('a') && ch <= char_code('z')) ||
  (ch >= char_code('A') && ch <= char_code('Z')) ||
  ch == char_code('_')
}

///|
/// Test whether *ch* is a valid identifier continuation character.
fn is_ident_continue(ch : Int) -> Bool {
  is_ident_start(ch) || (ch >= char_code('0') && ch <= char_code('9'))
}

///|
/// Test whether *ch* is an ASCII digit.
fn is_digit(ch : Int) -> Bool {
  ch >= char_code('0') && ch <= char_code('9')
}

///|
/// Check if two `Mode` values are equal (avoids needing Eq on priv enum).
fn mode_eq(a : Mode, b : Mode) -> Bool {
  match (a, b) {
    (Mode::Text, Mode::Text) => true
    (Mode::Expr, Mode::Expr) => true
    (Mode::Block, Mode::Block) => true
    (Mode::Comment, Mode::Comment) => true
    _ => false
  }
}

// ---------------------------------------------------------------------------
// Token dispatch
// ---------------------------------------------------------------------------

///|
/// Return the next token from the input stream together with the updated
/// lexer state.
fn Lexer::next_token(self : Lexer) -> (Token, Lexer) {
  if self.pos >= self.input.length() {
    let tok = make_token(TokenKind::Eof, self.line, self.col)
    return (tok, self)
  }

  match self.mode {
    Mode::Text => self.next_text_token()
    Mode::Expr => self.next_inner_token(Mode::Expr)
    Mode::Block => self.next_inner_token(Mode::Block)
    Mode::Comment => self.next_comment_token()
  }
}

// ---------------------------------------------------------------------------
// Text mode — scan until the next tag delimiter
// ---------------------------------------------------------------------------

///|
fn Lexer::next_text_token(self : Lexer) -> (Token, Lexer) {
  // Initialise the text buffer if not already tracking.
  let mut lex = if self.has_text {
    self
  } else {
    {
      ..self,
      text_start: self.pos,
      text_line: self.line,
      text_col: self.col,
      has_text: true,
    }
  }

  let input_len = lex.input.length()
  let brace = char_code('{')

  // Scan for the next tag opener.
  while lex.pos < input_len {
    let ch = lex.input[lex.pos].to_int()
    if ch == brace {
      if lex.peek_str("{{") {
        let (text_tok, lex2) = lex.emit_text_if_any()
        lex = lex2.advance(2)
        lex = { ..lex, mode: Mode::Expr }
        let tok = make_token(TokenKind::OpenVar, lex.line, lex.col - 1)
        let result_tok = match text_tok {
          Some(t) => t
          None => tok
        }
        return (result_tok, lex)
      } else if lex.peek_str("{%") {
        let (text_tok, lex2) = lex.emit_text_if_any()
        lex = lex2.advance(2)
        lex = { ..lex, mode: Mode::Block }
        let tok = make_token(TokenKind::OpenTag, lex.line, lex.col - 1)
        let result_tok = match text_tok {
          Some(t) => t
          None => tok
        }
        return (result_tok, lex)
      } else if lex.peek_str("{#") {
        let (text_tok, lex2) = lex.emit_text_if_any()
        lex = lex2.advance(2)
        lex = { ..lex, mode: Mode::Comment }
        match text_tok {
          Some(t) => return (t, lex)
          None => {
            lex = {
              ..lex,
              text_start: lex.pos,
              text_line: lex.line,
              text_col: lex.col,
              has_text: true,
            }
            return lex.next_comment_token()
          }
        }
      } else {
        // Lone '{' — include it in the text buffer.
        lex = lex.advance_one()
      }
    } else {
      lex = lex.advance_one()
    }
  }
  // End of input — emit whatever text remains.
  lex.emit_text()
}

///|
/// Emit the accumulated text buffer (if non-empty) and reset tracking.
fn Lexer::emit_text(self : Lexer) -> (Token, Lexer) {
  if !self.has_text || self.text_start >= self.pos {
    let tok = make_token(TokenKind::Eof, self.line, self.col)
    return (tok, { ..self, has_text: false })
  }
  let content = self.input[self.text_start:self.pos].to_owned()
  let tok = make_token(TokenKind::Text(content), self.text_line, self.text_col)
  (tok, { ..self, has_text: false })
}

///|
/// Emit accumulated text if any; otherwise return `None`.
fn Lexer::emit_text_if_any(self : Lexer) -> (Token?, Lexer) {
  if !self.has_text || self.text_start >= self.pos {
    return (None, { ..self, has_text: false })
  }
  let content = self.input[self.text_start:self.pos].to_owned()
  let tok = make_token(TokenKind::Text(content), self.text_line, self.text_col)
  (Some(tok), { ..self, has_text: false })
}

// ---------------------------------------------------------------------------
// Comment mode — skip until #}
// ---------------------------------------------------------------------------

///|
fn Lexer::next_comment_token(self : Lexer) -> (Token, Lexer) {
  let mut lex = self
  let input_len = lex.input.length()
  while lex.pos < input_len {
    if lex.peek_str("#}") {
      lex = lex.advance(2)
      lex = {
        ..lex,
        mode: Mode::Text,
        text_start: lex.pos,
        text_line: lex.line,
        text_col: lex.col,
        has_text: true,
      }
      // Return next real token (skip the comment entirely).
      return lex.next_token()
    } else {
      lex = lex.advance_one()
    }
  }
  // Unclosed comment.
  let tok = make_error("Unclosed comment", lex.line, lex.col)
  lex = { ..lex, mode: Mode::Text, has_text: false }
  (tok, lex)
}

// ---------------------------------------------------------------------------
// Inner tokeniser — shared by Expr and Block modes
// ---------------------------------------------------------------------------

///|
/// Tokenise content inside `{{ }}` (Expr) or `{% %}` (Block).
fn Lexer::next_inner_token(self : Lexer, mode : Mode) -> (Token, Lexer) {
  let is_block = mode_eq(mode, Mode::Block)

  // 1. Skip whitespace.
  let lex = self.skip_whitespace()

  // 2. Check for the closing delimiter.
  let close_delim = if mode_eq(mode, Mode::Expr) { "}}" } else { "%}" }
  let close_kind = if mode_eq(mode, Mode::Expr) {
    TokenKind::CloseVar
  } else {
    TokenKind::CloseTag
  }

  if lex.peek_str(close_delim) {
    let lex2 = lex.advance(2)
    let tok = make_token(close_kind, lex.line, lex.col)
    let lex3 = {
      ..lex2,
      mode: Mode::Text,
      text_start: lex2.pos,
      text_line: lex2.line,
      text_col: lex2.col,
      has_text: true,
    }
    return (tok, lex3)
  }

  // 3. EOF check.
  let ch_opt = lex.peek(0)
  match ch_opt {
    None => {
      let tok = make_error("Unclosed tag", lex.line, lex.col)
      let lex2 = { ..lex, mode: Mode::Text, has_text: false }
      return (tok, lex2)
    }
    Some(ch) => {
      // 4. Dispatch on the first character.
      let dq = char_code('"')
      let sq = char_code('\'')
      if ch == dq || ch == sq {
        return lex.read_string(ch)
      } else if is_digit(ch) {
        return lex.read_number()
      } else if is_ident_start(ch) {
        return lex.read_ident_or_keyword(is_block)
      } else {
        return lex.read_operator_or_punct()
      }
    }
  }
}

// ---------------------------------------------------------------------------
// String literal scanning
// ---------------------------------------------------------------------------

///|
/// Read a string literal delimited by *quote* (an `Int` code point for `"` or `'`).
fn Lexer::read_string(self : Lexer, quote : Int) -> (Token, Lexer) {
  let start_line = self.line
  let start_col = self.col
  let mut lex = self.advance_one() // consume opening quote
  let buf_start = lex.pos
  let input_len = lex.input.length()
  let backslash = char_code('\\')

  while lex.pos < input_len {
    let ch = lex.input[lex.pos].to_int()
    if ch == backslash {
      // Escape sequence — skip the backslash and the following char.
      lex = lex.advance(2)
    } else if ch == quote {
      // Closing quote.
      let content = lex.input[buf_start:lex.pos].to_owned()
      lex = lex.advance_one() // consume closing quote
      let tok = make_token(TokenKind::Str(content), start_line, start_col)
      return (tok, lex)
    } else {
      lex = lex.advance_one()
    }
  }
  // Unclosed string.
  let tok = make_error("Unclosed string literal", start_line, start_col)
  (tok, lex)
}

// ---------------------------------------------------------------------------
// Number scanning
// ---------------------------------------------------------------------------

///|
/// Read an integer or floating-point number.
fn Lexer::read_number(self : Lexer) -> (Token, Lexer) {
  let start_line = self.line
  let start_col = self.col
  let mut lex = self
  let mut is_float = false
  let input_len = lex.input.length()

  // Integer part.
  while lex.pos < input_len && is_digit(lex.input[lex.pos].to_int()) {
    lex = lex.advance_one()
  }

  // Optional fractional part.
  if lex.pos + 1 < input_len {
    let dot_ch = lex.input[lex.pos].to_int()
    let next_ch = lex.input[lex.pos + 1].to_int()
    if dot_ch == char_code('.') && is_digit(next_ch) {
      is_float = true
      lex = lex.advance_one() // consume '.'
      while lex.pos < input_len && is_digit(lex.input[lex.pos].to_int()) {
        lex = lex.advance_one()
      }
    }
  }

  // Optional exponent.
  if lex.pos < input_len {
    let e_ch = lex.input[lex.pos].to_int()
    if e_ch == char_code('e') || e_ch == char_code('E') {
      is_float = true
      lex = lex.advance_one()
      if lex.pos < input_len {
        let sign_ch = lex.input[lex.pos].to_int()
        if sign_ch == char_code('+') || sign_ch == char_code('-') {
          lex = lex.advance_one()
        }
      }
      while lex.pos < input_len && is_digit(lex.input[lex.pos].to_int()) {
        lex = lex.advance_one()
      }
    }
  }

  let num_str = self.input[self.pos:lex.pos].to_owned()

  if is_float {
    match parse_double(num_str) {
      Ok(v) => {
        let tok = make_token(TokenKind::Float(v), start_line, start_col)
        return (tok, lex)
      }
      Err(_) => {
        let tok = make_error(
          "Invalid float literal: " + num_str,
          start_line,
          start_col,
        )
        return (tok, lex)
      }
    }
  } else {
    match parse_int64(num_str) {
      Ok(v) => {
        let tok = make_token(TokenKind::Int(v), start_line, start_col)
        return (tok, lex)
      }
      Err(_) => {
        let tok = make_error(
          "Invalid integer literal: " + num_str,
          start_line,
          start_col,
        )
        return (tok, lex)
      }
    }
  }
}

///|
/// Simple base-10 Int64 parser.
fn parse_int64(s : String) -> Result[Int64, String] {
  if s.length() == 0 {
    return Err("empty")
  }
  let mut result = 0L
  let mut i = 0
  let len = s.length()
  let zero_code = char_code('0')
  while i < len {
    let ch = s[i].to_int()
    if ch >= zero_code && ch <= char_code('9') {
      let digit = (ch - zero_code).to_int64()
      result = result * 10L + digit
    } else {
      return Err("invalid character")
    }
    i = i + 1
  }
  Ok(result)
}

///|
/// Simple Double parser.
fn parse_double(s : String) -> Result[Double, String] {
  if s.length() == 0 {
    return Err("empty")
  }
  let mut result = 0.0
  let mut i = 0
  let mut sign = 1.0
  let len = s.length()
  let zero_code = char_code('0')
  let nine_code = char_code('9')

  // Sign.
  if i < len && s[i].to_int() == char_code('-') {
    sign = -1.0
    i = i + 1
  } else if i < len && s[i].to_int() == char_code('+') {
    i = i + 1
  }

  // Integer part.
  while i < len {
    let ch = s[i].to_int()
    if ch >= zero_code && ch <= nine_code {
      let digit = (ch - zero_code).to_int64().to_double()
      result = result * 10.0 + digit
      i = i + 1
    } else {
      break
    }
  }

  // Fractional part.
  if i < len && s[i].to_int() == char_code('.') {
    i = i + 1
    let mut frac = 0.1
    while i < len {
      let ch = s[i].to_int()
      if ch >= zero_code && ch <= nine_code {
        let digit = (ch - zero_code).to_int64().to_double()
        result = result + digit * frac
        frac = frac * 0.1
        i = i + 1
      } else {
        break
      }
    }
  }

  // Exponent.
  if i < len {
    let e_ch = s[i].to_int()
    if e_ch == char_code('e') || e_ch == char_code('E') {
      i = i + 1
      let mut exp_sign = 1
      if i < len && s[i].to_int() == char_code('+') {
        i = i + 1
      } else if i < len && s[i].to_int() == char_code('-') {
        exp_sign = -1
        i = i + 1
      }
      let mut exp_val = 0
      while i < len {
        let ch = s[i].to_int()
        if ch >= zero_code && ch <= nine_code {
          exp_val = exp_val * 10 + (ch - zero_code)
          i = i + 1
        } else {
          break
        }
      }
      // pow10 helper
      let mut pow = 1.0
      let mut j = 0
      while j < exp_val {
        pow = pow * 10.0
        j = j + 1
      }
      if exp_sign == 1 {
        result = result * pow
      } else {
        result = result / pow
      }
    }
  }

  Ok(sign * result)
}

// ---------------------------------------------------------------------------
// Identifier / keyword scanning
// ---------------------------------------------------------------------------

///|
/// Read an identifier and, in block mode, check whether it is a keyword.
fn Lexer::read_ident_or_keyword(
  self : Lexer,
  is_block : Bool,
) -> (Token, Lexer) {
  let start_line = self.line
  let start_col = self.col
  let mut lex = self
  let input_len = lex.input.length()

  while lex.pos < input_len && is_ident_continue(lex.input[lex.pos].to_int()) {
    lex = lex.advance_one()
  }

  let ident = self.input[self.pos:lex.pos].to_owned()
  let kind = match_keyword(ident, is_block)
  let tok = make_token(kind, start_line, start_col)
  (tok, lex)
}

///|
/// Map an identifier string to the appropriate keyword token (if any).
fn match_keyword(ident : String, is_block : Bool) -> TokenKind {
  // Expression-level keywords (recognised everywhere).
  if ident == "true" {
    return TokenKind::Bool(true)
  }
  if ident == "false" {
    return TokenKind::Bool(false)
  }
  if ident == "and" {
    return TokenKind::And
  }
  if ident == "or" {
    return TokenKind::Or
  }
  if ident == "not" {
    return TokenKind::Not
  }
  if ident == "in" {
    return TokenKind::In
  }

  // Block-level keywords (only inside {% %}).
  if is_block {
    if ident == "if" {
      return TokenKind::If
    }
    if ident == "elif" {
      return TokenKind::Elif
    }
    if ident == "else" {
      return TokenKind::Else
    }
    if ident == "endif" {
      return TokenKind::Endif
    }
    if ident == "for" {
      return TokenKind::For
    }
    if ident == "endfor" {
      return TokenKind::Endfor
    }
    if ident == "block" {
      return TokenKind::Block
    }
    if ident == "endblock" {
      return TokenKind::Endblock
    }
    if ident == "extends" {
      return TokenKind::Extends
    }
    if ident == "macro" {
      return TokenKind::Macro
    }
    if ident == "endmacro" {
      return TokenKind::Endmacro
    }
    if ident == "include" {
      return TokenKind::Include
    }
  }

  TokenKind::Ident(ident)
}

// ---------------------------------------------------------------------------
// Operator / punctuation scanning
// ---------------------------------------------------------------------------

///|
/// Try to match an operator or punctuation token at the current position.
/// Falls back to `Error` on unrecognised characters.
fn Lexer::read_operator_or_punct(self : Lexer) -> (Token, Lexer) {
  let line = self.line
  let col = self.col

  // Multi-character operators first.
  if self.peek_str("==") {
    let tok = make_token(TokenKind::Eq, line, col)
    return (tok, self.advance(2))
  }
  if self.peek_str("!=") {
    let tok = make_token(TokenKind::NotEq, line, col)
    return (tok, self.advance(2))
  }
  if self.peek_str("<=") {
    let tok = make_token(TokenKind::LtEq, line, col)
    return (tok, self.advance(2))
  }
  if self.peek_str(">=") {
    let tok = make_token(TokenKind::GtEq, line, col)
    return (tok, self.advance(2))
  }

  // Single-character tokens.
  let ch = self.peek(0).unwrap()
  let kind = match_single_char(ch)
  match kind {
    Some(k) => {
      let tok = make_token(k, line, col)
      (tok, self.advance_one())
    }
    None => {
      let ch_str = "0x" + ch.to_int64().to_string()
      let tok = make_error("Unexpected character: " + ch_str, line, col)
      (tok, self.advance_one())
    }
  }
}

///|
/// Map a single character code (`Int`) to its token kind (if recognised).
fn match_single_char(ch : Int) -> TokenKind? {
  if ch == char_code('+') {
    return Some(TokenKind::Plus)
  }
  if ch == char_code('-') {
    return Some(TokenKind::Minus)
  }
  if ch == char_code('*') {
    return Some(TokenKind::Star)
  }
  if ch == char_code('/') {
    return Some(TokenKind::Slash)
  }
  if ch == char_code('%') {
    return Some(TokenKind::Percent)
  }
  if ch == char_code('<') {
    return Some(TokenKind::Lt)
  }
  if ch == char_code('>') {
    return Some(TokenKind::Gt)
  }
  if ch == char_code('|') {
    return Some(TokenKind::Pipe)
  }
  if ch == char_code(':') {
    return Some(TokenKind::Colon)
  }
  if ch == char_code(',') {
    return Some(TokenKind::Comma)
  }
  if ch == char_code('.') {
    return Some(TokenKind::Dot)
  }
  if ch == char_code('(') {
    return Some(TokenKind::LParen)
  }
  if ch == char_code(')') {
    return Some(TokenKind::RParen)
  }
  if ch == char_code('[') {
    return Some(TokenKind::LBracket)
  }
  if ch == char_code(']') {
    return Some(TokenKind::RBracket)
  }
  if ch == char_code('=') {
    return Some(TokenKind::Assign)
  }
  if ch == char_code('~') {
    return Some(TokenKind::Tilde)
  }
  None
}
