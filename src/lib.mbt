// Copyright (c) 2024 LinZeming
// Released under the MIT License
//
// MoonBit Template Engine — A Jinja2/Tera-inspired template rendering engine.
//
// # Quick Start
//
// ```
// let tokens = tokenize("Hello, {{ name }}!")?
// let ctx = Context::new().set("name", Str("World"))
// let parser = Parser::new(tokens)
// let evaluator = Evaluator::new(ctx)
// ```

///|
/// Version of the template engine.
pub const VERSION : String = "0.1.0"

// ---------------------------------------------------------------------------
// Public API overview
// ---------------------------------------------------------------------------
//
// Types:
//   Token, TokenKind    — lexer tokens (lexer.mbt)
//   Value, Expr, Node,
//   BinOpKind, UnaryOpKind,
//   ElifBranch, Template — AST nodes (ast.mbt)
//   Context             — nested-scope variable storage (context.mbt)
//   Evaluator           — expression evaluator (evaluator.mbt)
//   Parser              — token stream → AST parser (parser.mbt)
//
// Functions:
//   tokenize(input)     — lexer.mbt
//   Context::new / new_child / get / set  — context.mbt
//   Evaluator::new / eval                 — evaluator.mbt
//   Parser::new / parse_template / parse_expression  — parser.mbt
//   Value::to_string / is_truthy / type_name  — ast.mbt
