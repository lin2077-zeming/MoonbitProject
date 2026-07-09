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
// ```

///|
/// Version of the template engine.
pub const VERSION : String = "0.1.0"

// ---------------------------------------------------------------------------
// Public API overview
// ---------------------------------------------------------------------------
//
// Types:
//   Token, TokenKind           — lexer tokens (lexer.mbt)
//   Value, Expr, Node,
//   BinOpKind, UnaryOpKind,
//   ElifBranch                  — AST nodes (ast.mbt)
//   Context                     — nested-scope storage (context.mbt)
//   Evaluator                   — expression evaluator (evaluator.mbt)
//   Parser                      — token → AST parser (parser.mbt)
//   Renderer                    — AST → string renderer (renderer.mbt)
//   Template                    — parse + render entry (template.mbt)
//   FilterRegistry, FilterFn    — filter system (filters.mbt)
//   TemplateLoader              — include resolver (loader.mbt)
//
//   ErrorKind, SourceLocation,
//   TemplateError              — unified error types (errors.mbt)
//
// Key functions:
//   tokenize(input) → Result[Array[Token], String]
//   Template::parse(source) → Result[Template, TemplateError]
//   Template::render(ctx) → Result[String, TemplateError]
//   Parser::make_error(kind, msg) → TemplateError
//   TemplateError::to_string() → String (human-readable)
//   extract_snippet(source, line) → String
