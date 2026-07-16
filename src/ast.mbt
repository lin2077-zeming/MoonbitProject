// ---------------------------------------------------------------------------
// MoonTera — AST node definitions
//
// Defines the runtime Value type, expression nodes (Expr), statement-level
// template nodes (Node), and the Template struct.
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Runtime values
// ---------------------------------------------------------------------------

/// All values that can appear during template evaluation.
pub enum Value {
  Null
  Bool(Bool)
  Int(Int64)
  Float(Double)
  Str(String)
  Array(Array[Value])
  Object(Map[String, Value])
}

/// Convert a Value to its string representation (for display in templates).
pub fn Value::to_string(self : Value) -> String {
  match self {
    Value::Null => "null"
    Value::Bool(b) => if b { "true" } else { "false" }
    Value::Int(n) => n.to_string()
    Value::Float(f) => f.to_string()
    Value::Str(s) => s
    Value::Array(_) => "[Array]"
    Value::Object(_) => "[Object]"
  }
}

/// Check if a Value is "truthy" for conditionals.
/// Falsy: Null, Bool(false), empty Str, Int(0), Float(0.0), empty Array, empty Object
pub fn Value::is_truthy(self : Value) -> Bool {
  match self {
    Value::Null => false
    Value::Bool(b) => b
    Value::Int(n) => n != 0L
    Value::Float(f) => f != 0.0
    Value::Str(s) => s != ""
    Value::Array(arr) => arr.length() > 0
    Value::Object(m) => m.length() > 0
  }
}

// ---------------------------------------------------------------------------
// Eq for Value — enables == and != comparisons in tests and evaluator
// ---------------------------------------------------------------------------

impl Eq for Value with equal(a, b) {
  match (a, b) {
    (Value::Null, Value::Null) => true
    (Value::Bool(x), Value::Bool(y)) => x == y
    (Value::Int(x), Value::Int(y)) => x == y
    (Value::Float(x), Value::Float(y)) => x == y
    (Value::Str(x), Value::Str(y)) => x == y
    (Value::Int(x), Value::Float(y)) => x.to_double() == y
    (Value::Float(x), Value::Int(y)) => x == y.to_double()
    _ => false
  }
}

// ---------------------------------------------------------------------------
// Binary operator kinds
// ---------------------------------------------------------------------------

pub enum BinOpKind {
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
}

/// Get the precedence level for a binary operator (higher = binds tighter).
pub fn BinOpKind::precedence(self : BinOpKind) -> Int {
  match self {
    BinOpKind::Or => 1
    BinOpKind::And => 2
    BinOpKind::Eq | BinOpKind::Neq | BinOpKind::Lt | BinOpKind::Gt | BinOpKind::Le | BinOpKind::Ge => 3
    BinOpKind::Add | BinOpKind::Sub => 4
    BinOpKind::Mul | BinOpKind::Div | BinOpKind::Mod => 5
  }
}

/// Convert a TokenKind keyword or operator to a BinOpKind (if applicable).
pub fn BinOpKind::from_token_kind(kind : TokenKind) -> Option[BinOpKind] {
  match kind {
    TokenKind::Plus => Some(BinOpKind::Add)
    TokenKind::Minus => Some(BinOpKind::Sub)
    TokenKind::Star => Some(BinOpKind::Mul)
    TokenKind::Slash => Some(BinOpKind::Div)
    TokenKind::Percent => Some(BinOpKind::Mod)
    TokenKind::Eq => Some(BinOpKind::Eq)
    TokenKind::NotEq => Some(BinOpKind::Neq)
    TokenKind::Lt => Some(BinOpKind::Lt)
    TokenKind::Gt => Some(BinOpKind::Gt)
    TokenKind::LtEq => Some(BinOpKind::Le)
    TokenKind::GtEq => Some(BinOpKind::Ge)
    TokenKind::And => Some(BinOpKind::And)
    TokenKind::Or => Some(BinOpKind::Or)
    _ => None
  }
}

// ---------------------------------------------------------------------------
// Unary operator kinds
// ---------------------------------------------------------------------------

pub enum UnaryOpKind {
  Not
  Neg
}

// ---------------------------------------------------------------------------
// Expression nodes
// ---------------------------------------------------------------------------

/// Expressions — everything that evaluates to a Value.
pub enum Expr {
  /// Literal value: {{ 42 }}, {{ "hello" }}, {{ true }}
  Literal(Value)
  /// Variable lookup: {{ user }}
  Variable(String)
  /// Member access: {{ user.name }}
  Member(Expr, String)
  /// Index access: {{ items[0] }}
  Index(Expr, Expr)
  /// Function / filter call: {{ input("name") }}
  Call(String, Array[Expr])
  /// Binary operation: {{ a + b }}, {{ x and y }}
  BinOp(Expr, BinOpKind, Expr)
  /// Unary operation: {{ -x }}, {{ not flag }}
  UnaryOp(UnaryOpKind, Expr)
  /// Filter chain call: {{ value | upper | truncate:100 }}
  /// Nested: Filter(Filter(Variable("value"), "upper", []), "truncate", [Literal(100)])
  Filter(Expr, String, Array[Expr])
}

// ---------------------------------------------------------------------------
// Statement-level template nodes
// ---------------------------------------------------------------------------

/// Template statements — the top-level structure of a compiled template.
pub enum Node {
  /// Plain text emitted verbatim.
  Text(String)
  /// {{ expr }} — evaluate and emit.
  Output(Expr)
  /// {% if cond %} then {% elif cond %} elif... {% else %} else {% endif %}
  /// Fields: condition, then_body, elif_list [(cond, body), ...], else_body
  If(Expr, Array[Node], Array[(Expr, Array[Node])], Array[Node])
  /// {% for var in iterable %} body {% endfor %}
  For(String, Expr, Array[Node])
  /// {% block name %} body {% endblock %}
  Block(String, Array[Node])
  /// {% extends "parent" %}
  Extends(String)
  /// {% include "partial" %}
  Include(String)
  /// {% macro name(args) %} body {% endmacro %}
  Macro(String, Array[String], Array[Node])
  /// {% filter name %} body {% endfilter %}  (block-level filter)
  FilterBlock(String, Array[Expr], Array[Node])
}

// ---------------------------------------------------------------------------
// Compiled template
// ---------------------------------------------------------------------------

/// A macro definition: name, parameter names, and body nodes.
pub struct MacroDef {
  name : String
  params : Array[String]
  body : Array[Node]
}

/// A compiled (parsed) template ready for rendering.
pub struct Template {
  name : String
  nodes : Array[Node]
  parent : Option[String]              // parent template name (from {% extends %})
  blocks : Map[String, Array[Node]]    // extracted top-level block definitions
  block_names : Array[String]          // block names in definition order (for iteration)
}
