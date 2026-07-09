// Copyright (c) 2024 LinZeming
// Released under the MIT License
//
// AST — Abstract Syntax Tree node definitions for the template engine.
//
// The AST is produced by the parser and consumed by the renderer.  It
// represents the complete structure of a compiled template.

// ---------------------------------------------------------------------------
// Runtime value type
// ---------------------------------------------------------------------------

///|
/// Runtime value — used for template context data and literal values.
pub(all) enum Value {
  Null
  Bool(Bool)
  Int(Int64)
  Float(Double)
  Str(String)
  Array(Array[Value])
  Object(Map[String, Value])
} derive(Debug)

///|
/// Convert a `Value` to its string representation (for output).
pub fn Value::to_string(self : Value) -> String {
  match self {
    Null => "null"
    Bool(b) => if b { "true" } else { "false" }
    Int(i) => i.to_string()
    Float(f) => f.to_string()
    Str(s) => s
    Array(arr) => {
      let mut result = "["
      let len = arr.length()
      for i = 0; i < len; i = i + 1 {
        result = result + arr[i].to_string()
        if i + 1 < len {
          result = result + ", "
        }
      }
      result + "]"
    }
    Object(_) => "[object]"
  }
}

///|
/// Test whether a value is "truthy" (for use in `if` conditions).
pub fn Value::is_truthy(self : Value) -> Bool {
  match self {
    Null => false
    Bool(b) => b
    Int(i) => i != 0L
    Float(f) => f != 0.0
    Str(s) => s != ""
    Array(arr) => arr.length() > 0
    Object(m) => m.length() > 0
  }
}

///|
/// Return a human-readable type name for this value.
pub fn Value::type_name(self : Value) -> String {
  match self {
    Null => "null"
    Bool(_) => "bool"
    Int(_) => "int"
    Float(_) => "float"
    Str(_) => "string"
    Array(_) => "array"
    Object(_) => "object"
  }
}

// ---------------------------------------------------------------------------
// Expression nodes
// ---------------------------------------------------------------------------

///|
/// Binary operator kinds.
pub(all) enum BinOpKind {
  Add
  Sub
  Mul
  Div
  Mod
  Eq
  Neq
  Lt
  Gt
  Le
  Ge
  And
  Or
} derive(Debug)

///|
/// Unary operator kinds.
pub(all) enum UnaryOpKind {
  Not
  Neg
} derive(Debug)

///|
/// Expression node — evaluates to a `Value` at render time.
pub(all) enum Expr {
  Literal(Value)                       // literal value (42, "hello", true, …)
  Variable(String)                     // variable reference (user.name)
  Member(Expr, String)                 // member access  a.b.c
  Index(Expr, Expr)                    // index access    a[b]
  Call(String, Array[Expr])            // function / filter call
  BinOp(Expr, BinOpKind, Expr)         // binary operation a + b, a and b
  UnaryOp(UnaryOpKind, Expr)           // unary operation  not x, -x
  Filter(Expr, String, Array[Expr])    // filter chain:  value | filter(args)
} derive(Debug)

// ---------------------------------------------------------------------------
// Template statement nodes
// ---------------------------------------------------------------------------

///|
/// A single elif (or else) branch inside an `{% if %}` block.
///
/// `condition = None` represents the final `{% else %}` clause.
pub(all) struct ElifBranch {
  condition : Option[Expr]
  body : Array[Node]
} derive(Debug)

///|
/// Template node — a top-level statement inside a template.
pub(all) enum Node {
  Text(String)                                       // plain text output
  Output(Expr)                                       // {{ expr }} interpolation
  If(Expr, Array[Node], Array[ElifBranch], Array[Node]) // {% if cond %}…{% elif %}…{% else %}…{% endif %}
  For(String, Expr, Array[Node])                     // {% for var in iterable %}…{% endfor %}
  Block(String, Array[Node])                         // {% block name %}…{% endblock %}
  Extends(String)                                    // {% extends "parent.html" %}
  Include(String)                                    // {% include "partial.html" %}
  Macro(String, Array[String], Array[Node])          // {% macro name(args) %}…{% endmacro %}
  FilterBlock(String, Array[Expr], Array[Node])      // {% filter name(args) %}…{% endfilter %}
} derive(Debug)

///|
/// A compiled template — the output of parsing.
pub(all) struct Template {
  name : String
  nodes : Array[Node]
} derive(Debug)
