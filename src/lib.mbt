// Copyright (c) 2024 LinZeming
// Released under the MIT License
//
// MoonBit Template Engine — A Jinja2/Tera-inspired template rendering engine.
//
// # Quick Start
//
// ```
// let tpl = Template::parse("Hello, {{ name }}!")?
// let ctx = Context::new().set("name", Str("World"))
// let result = tpl.render(ctx)?
// assert_eq!(result, "Hello, World!")
// ```

///|
/// Version of the template engine.
pub const VERSION : String = "0.1.0"

// ---------------------------------------------------------------------------
// Public API overview
// ---------------------------------------------------------------------------
//
// Types:
//   Token, TokenKind      — lexer tokens (lexer.mbt)
//   Value, Expr, Node,
//   BinOpKind, UnaryOpKind,
//   ElifBranch             — AST nodes (ast.mbt)
//   Context                — nested-scope variable storage (context.mbt)
//   Evaluator              — expression evaluator (evaluator.mbt)
//   Parser                 — token stream → AST parser (parser.mbt)
//   Renderer               — AST → string renderer (renderer.mbt)
//   Template               — parse + render entry point (template.mbt)
//
// Key functions:
//   tokenize(input) → Result[Array[Token], String]
//   Template::parse(source) → Result[Template, String]
//   Template::render(ctx) → Result[String, String]
