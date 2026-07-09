// Copyright (c) 2024 LinZeming
// Released under the MIT License
//
// MoonBit Template Engine — A Jinja2/Tera-inspired template rendering engine.
//
// # Quick Start
//
// ```
// let env = Environment::new()
//   .add_template("hello", "Hello, {{ name }}!")?
//
// let mut data = Map::new()
// data["name"] = Value::String("World")
//
// let result = env.render("hello", Value::Map(data))?
// assert_eq!(result, "Hello, World!")
// ```

/// Version of the template engine.
pub const VERSION : String = "0.1.0"

// ---------------------------------------------------------------------------
// Public re-exports (to be added as modules are implemented)
// ---------------------------------------------------------------------------

// TODO: Uncomment as each module is implemented
// pub use environment::{ Environment, AutoEscapeMode }
// pub use template::{ Template }
// pub use context::{ Context, LoopState }
// pub use value::{ Value }
// pub use errors::{ TemplateError }
// pub use ast::{
//   Node, Expr, BinaryOp, UnaryOp,
//   TextNode, VariableNode, BlockNode, IfNode, ForNode,
//   IncludeNode, ExtendsNode, SetNode, MacroNode, MacroArg,
//   CallNode, FilterBlockNode, RawNode, FilterCall,
//   SourcePos,
// }
// pub use filters::{ register_all as register_all_filters }

/// Quick one-shot render: parse and render a template string with given data.
///
/// This is the simplest API entry point. For repeated rendering of the same
/// template, use `Environment` to cache the parsed template.
pub fn render(
  source : String,
  data : Value
) -> Result[String, TemplateError] {
  Environment::new().render_str(source, data)
}
