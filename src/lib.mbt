// Copyright (c) 2024 LinZeming
// Released under the MIT License
//
// MoonBit Template Engine — A Jinja2/Tera-inspired template rendering engine.
//
// # Quick Start
//
// ```
// let tokens = tokenize("Hello, {{ name }}!")?
// let parser = Parser::new(tokens)
// let (nodes, _) = parser.parse_template()?
// ```

///|
/// Version of the template engine.
pub const VERSION : String = "0.1.0"

// ---------------------------------------------------------------------------
// Public API overview
// ---------------------------------------------------------------------------
//
// Types (auto-accessible package-wide):
//   Token, TokenKind  — from lexer.mbt
//   Value, Expr, Node, BinOpKind, UnaryOpKind, ElifBranch, Template  — from ast.mbt
//   Parser            — from parser.mbt
//
// Functions:
//   tokenize(input) -> Result[Array[Token], String]          — lexer.mbt
//   Parser::new(tokens) -> Parser                            — parser.mbt
//   Parser::parse_template() -> Result[(Array[Node], Parser), String]  — parser.mbt
//   Value::to_string() / Value::is_truthy()                  — ast.mbt
