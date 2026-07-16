# MoonTera Architecture Design

> MoonTera — a MoonBit template rendering engine inspired by Rust's
> [Tera](https://keats.github.io/tera/) and Python's
> [Jinja2](https://jinja.palletsprojects.com/).

---

## Table of Contents

1. [Module Division](#1-module-division)
2. [Template Syntax Specification](#2-template-syntax-specification)
3. [AST Node Types](#3-ast-node-types)
4. [Core Data Structures](#4-core-data-structures)
5. [Rendering Flow](#5-rendering-flow)
6. [Project Directory Layout](#6-project-directory-layout)

---

## 1. Module Division

Each module lives under `src/` as a separate `.mbt` file. The `src/` directory is a
MoonBit **sub-package** of the root library package.

```
src/
├── moon.pkg         # sub-package config: imports from moonbitlang/core
├── lib.mbt          # public API: Template::parse / Template::render
├── errors.mbt       # unified error types with source positions
├── lexer.mbt        # Token enum + lexer (template string → Token stream)
├── ast.mbt          # AST node enums (Stmt, Expr, ...)
├── parser.mbt       # parser (Token stream → AST)
├── evaluator.mbt    # expression evaluator (Expr + Context → Value)
├── renderer.mbt     # renderer (AST + Context → String)
├── context.mbt      # Context: nested-scope variable environment
└── filters.mbt      # filter system (built-in + registration)
```

| Module | Responsibility | Primary Input | Primary Output |
|--------|---------------|---------------|----------------|
| `errors` | Unified error types with source-location tracking | — | `ErrorKind`, `SourcePos`, `TemplateError` |
| `lexer` | Tokenise template source text | `String` | `Array[Token]` (or `Result[_, TemplateError]`) |
| `ast` | Data definitions for every AST node | — | `Stmt`, `Expr`, `BinOp`, etc. |
| `parser` | Build AST from flat token stream | `Array[Token]` | `Result[Array[Stmt], TemplateError]` |
| `evaluator` | Evaluate an expression in a given context | `Expr`, `Context` | `Result[Value, TemplateError]` |
| `renderer` | Walk AST, evaluate embedded expressions, produce output | `Array[Stmt]`, `Context` | `Result[String, TemplateError]` |
| `context` | Nested-scope variable store | — | `Context` (with `push` / `pop` / `get` / `set`) |
| `filters` | Built-in filters + user registration | filter name + `Value` | `Result[Value, TemplateError]` |
| `lib` | Public façade: `Template` struct, `parse`, `render` | template source | compiled template / rendered string |

### Dependency Graph

```
lib
 ├── parser ──→ lexer
 │     └──→ ast
 ├── renderer ──→ evaluator ──→ context
 │     │                         └──→ filters
 │     └──→ ast
 └── errors (used everywhere)
```

---

## 2. Template Syntax Specification

### 2.1 Delimiters

| Delimiter | Purpose |
|-----------|---------|
| `{{ ... }}` | **Output** — evaluate expression, escape HTML, print |
| `{% ... %}` | **Tag** — control flow (`if`, `for`, `extends`, …) |
| `{# ... #}` | **Comment** — ignored entirely (may span multiple lines) |

### 2.2 Variable Output

```
{{ username }}
{{ user.name }}
{{ items[0] }}
{{ "literal string" }}
{{ 42 }}
{{ true }}
```

### 2.3 Filters

Filters are applied with the pipe `|` operator. Arguments are separated by `:`.

```
{{ name | upper }}
{{ price | round:2 }}
{{ body | escape | truncate:100 }}
{{ value | default:"N/A" }}
```

Built-in filters (see §4.1 for implementation):

| Filter | Args | Description |
|--------|------|-------------|
| `lower` | — | Convert to lowercase |
| `upper` | — | Convert to uppercase |
| `trim` | — | Remove leading/trailing whitespace |
| `length` | — | Length of string / array |
| `escape` | — | HTML-escape (`<` → `&lt;`, etc.) |
| `safe` | — | Mark string as safe (skip auto-escaping) |
| `default` | `val` | Return `val` if value is nil/empty |
| `first` | — | First element of array |
| `last` | — | Last element of array |
| `join` | `sep` | Join array elements with separator |
| `reverse` | — | Reverse a string or array |
| `abs` | — | Absolute value |
| `int` | — | Convert to integer |
| `float` | — | Convert to float |
| `string` | — | Convert to string |
| `round` | `n` | Round float to `n` decimal places |
| `slice` | `start`, `end?` | Slice array/string |

### 2.4 Comments

```
{# This is a single-line comment #}

{#
  This is a
  multi-line comment
#}
```

### 2.5 Conditionals

```
{% if user.is_admin %}
  <p>Admin panel</p>
{% elif user.is_moderator %}
  <p>Mod tools</p>
{% else %}
  <p>Guest view</p>
{% endif %}
```

Logical operators: `and`, `or`, `not`. Comparisons: `==`, `!=`, `<`, `>`, `<=`, `>=`.

### 2.6 For Loops

```
{% for item in items %}
  <li>{{ item.name }}</li>
{% endfor %}
```

Key-value iteration (maps):

```
{% for key, value in map %}
  {{ key }}: {{ value }}
{% endfor %}
```

#### Loop Built-in Variables

Inside a `for` body, `loop` is an implicit object:

| Variable | Description |
|----------|-------------|
| `loop.index` | 1-based iteration counter |
| `loop.index0` | 0-based iteration counter |
| `loop.first` | `true` on the first iteration |
| `loop.last` | `true` on the last iteration |
| `loop.length` | Total number of items |

### 2.7 Template Inheritance

**Base template** (`base.html`):

```html
<html>
<head><title>{% block title %}Default{% endblock %}</title></head>
<body>{% block content %}{% endblock %}</body>
</html>
```

**Child template**:

```
{% extends "base.html" %}
{% block title %}Home{% endblock %}
{% block content %}<p>Welcome!</p>{% endblock %}
```

Rules:
- `extends` must be the **first** tag in the template.
- A child may override any number of blocks.
- Blocks not overridden keep the parent's default content.
- `{{ super() }}` inside a block renders the parent's block content.

### 2.8 Includes

```
{% include "header.html" %}
{% include "partials/" + name + ".html" %}
```

The included template shares the **current context** — it sees the same variables.

### 2.9 Macros

```
{% macro input(name, value="", type="text") %}
  <input type="{{ type }}" name="{{ name }}" value="{{ value }}">
{% endmacro %}

{{ input("username") }}
{{ input("password", type="password") }}
```

Macros are function-like and support default parameter values.

### 2.10 Raw / Verbatim

```
{% raw %}
  Here {{ nothing }} is processed, {% tags %} are ignored.
{% endraw %}
```

### 2.11 Whitespace Control

A leading `-` inside a delimiter trims preceding whitespace; a trailing `-` trims
following whitespace (same as Jinja2):

```
{%- if cond -%}
  no surrounding whitespace
{%- endif -%}
```

---

## 3. AST Node Types

All node types are defined as MoonBit `enum`s in `src/ast.mbt`.

### 3.1 Binary & Unary Operators

```moonbit
// src/ast.mbt

/// Binary operators for expressions.
enum BinOp {
  Add        // +
  Sub        // -
  Mul        // *
  Div        // /
  Mod        // %
  Eq         // ==
  NotEq      // !=
  Lt         // <
  Gt         // >
  LtE        // <=
  GtE        // >=
  And        // and
  Or         // or
  Concat     // ~  (string concatenation)
}

/// Unary operators for expressions.
enum UnaryOp {
  Neg        // - (numeric negation)
  Not        // not (logical negation)
}
```

### 3.2 Expressions

```moonbit
/// Runtime value types used during evaluation.
enum Value {
  Nil
  Bool(Bool)
  Int(Int64)
  Float(Double)
  String(String)
  Array(Array[Value])
  Map(Map[String, Value])
}

/// A filter invocation: name + optional argument.
struct FilterCall {
  name : String
  arg : Option[Expr]
}

/// Expression nodes — everything that evaluates to a Value.
enum Expr {
  // Literals
  Literal(Value)
  // Variable lookup: {{ foo }}
  Ident(String)
  // Unary operation: not x, -x
  Unary(UnaryOp, Box[Expr])
  // Binary operation: a + b, x and y
  Binary(Box[Expr], BinOp, Box[Expr])
  // Member access: user.name
  Member(Box[Expr], String)
  // Index access: items[0]
  Index(Box[Expr], Box[Expr])
  // Filter chain: value | upper | truncate:100
  Filter(Box[Expr], Array[FilterCall])
  // Ternary / test: x is defined
  Test(String, Box[Expr])
  // Function call (for macros in scope)
  Call(String, Array[Expr])
  // String concatenation short-hand
  Concat(Box[Expr], Box[Expr])
}
```

> **Note** — `Box[Expr]` is used to prevent infinite-size types in recursive
> enum definitions.  In practice this is a thin wrapper struct.

### 3.3 Statements

```moonbit
/// Top-level template nodes.  A template is an Array[Stmt].
enum Stmt {
  // Raw text to emit verbatim
  Text(String)
  // {{ expr }} — evaluate, escape, emit
  Variable(Expr)
  // {# comment #}
  Comment(String)
  // {% if cond %} ... {% elif cond2 %} ... {% else %} ... {% endif %}
  // elifs is Array[(condition, body)]; else_body is optional
  If(Expr, Array[Stmt], Array[(Expr, Array[Stmt])], Option[Array[Stmt]])
  // {% for var in expr %} ... {% endfor %}
  // key_var is Some(k) for {% for k, v in map %}
  For(String, Option[String], Expr, Array[Stmt])
  // {% block name %} ... {% endblock %}
  Block(String, Array[Stmt])
  // {% extends "parent" %}
  Extends(String)
  // {% include "partial" %}
  Include(String)
  // {% macro name(args) %} ... {% endmacro %}
  Macro(String, Array[String], Array[Stmt])
  // {% set var = expr %}
  Set(String, Expr)
  // {% raw %} ... {% endraw %}
  Raw(String)
}
```

### 3.4 Token Types (for the Lexer)

```moonbit
// src/lexer.mbt

enum Token {
  // Literal text between tags
  Text(String)
  // Delimiters
  VariableStart       // {{
  VariableEnd         // }}
  BlockStart          // {%
  BlockEnd            // %}
  CommentStart        // {#
  CommentEnd          // #}
  // Values
  Ident(String)
  StringLit(String)
  IntLit(Int64)
  FloatLit(Double)
  BoolLit(Bool)
  NilLit
  // Punctuation
  Pipe                // |
  Dot                 // .
  Comma               // ,
  Colon               // :
  LParen              // (
  RParen              // )
  LBracket            // [
  RBracket            // ]
  LBrace              // {
  RBrace              // }
  Tilde               // ~
  // Operators
  Eq                  // =
  EqEq                // ==
  NotEq               // !=
  Lt                  // <
  Gt                  // >
  LtEq                // <=
  GtEq                // >=
  Plus                // +
  Minus               // -
  Star                // *
  Slash               // /
  Percent             // %
  Not                 // !
  // Keywords (case-insensitive)
  KwAnd
  KwOr
  KwNot
  KwIf
  KwElif
  KwElse
  KwEndif
  KwFor
  KwIn
  KwEndfor
  KwExtends
  KwBlock
  KwEndblock
  KwInclude
  KwMacro
  KwEndmacro
  KwSet
  KwRaw
  KwEndraw
  KwIs
  KwTrue
  KwFalse
  KwNil
  // End of input
  EOF
}
```

---

## 4. Core Data Structures

### 4.1 Template

```moonbit
// src/lib.mbt

/// A compiled (parsed) template ready for rendering.
struct Template {
  name : String                    // logical name, e.g. "index.html"
  source : String                  // raw source text (kept for error messages)
  statements : Array[Stmt]         // parsed AST
  // Template inheritance
  parent : Option[String]          // parent template name (from {% extends %})
  blocks : Map[String, Array[Stmt]] // block name → body
  macros : Map[String, (Array[String], Array[Stmt])] // macro name → (params, body)
}

/// Parse raw source into a compiled Template.
fn parse(name : String, source : String) -> Result[Template, TemplateError]! { ... }

/// Render a compiled template with the given context.
fn render(self : Template, ctx : Context) -> Result[String, TemplateError]! { ... }

/// Convenience: one-shot parse + render.
fn render_str(name : String, source : String, ctx : Context) -> Result[String, TemplateError]! {
  let tpl = parse(name, source)?
  tpl.render(ctx)
}
```

### 4.2 Context — Nested Scope Variable Environment

```moonbit
// src/context.mbt

/// A single scope frame — a mapping from variable name to Value.
struct Scope {
  variables : Map[String, Value]
}

/// The template context holds a stack of scopes.
/// Variable lookup walks from innermost to outermost scope.
struct Context {
  scopes : Array[Scope]
  // Optional: auto-escape mode (default true for HTML)
  auto_escape : Bool
}

/// Create a new context with one global scope.
fn Context::new() -> Context { ... }

/// Create a context pre-populated with a JSON-like value.
fn Context::from_value(value : Value) -> Context { ... }

/// Push a new (empty) scope onto the stack.  Used for for-loop bodies.
fn Context::push_scope(self : Context) -> Unit { ... }

/// Pop the innermost scope.  Used when leaving a for-loop body.
fn Context::pop_scope(self : Context) -> Unit { ... }

/// Look up a variable by name.  Returns None if not found.
fn Context::get(self : Context, name : String) -> Option[Value] { ... }

/// Set a variable in the innermost scope.
fn Context::set(self : Context, name : String, value : Value) -> Unit { ... }

/// Insert a (key, value) pair into the global (outermost) scope.
fn Context::insert_global(self : Context, name : String, value : Value) -> Unit { ... }
```

#### Scope Resolution Example

```
{% set x = 1 %}            ← outer scope: {x: 1}
{% for item in items %}    ← push new scope: {item: ..., loop: ...}
  {{ x }}                  ← walks up: finds x in outer scope → 1
  {{ item }}               ← found in inner scope
{% endfor %}               ← pop inner scope
```

### 4.3 Errors

```moonbit
// src/errors.mbt

/// A position in source text.
struct SourcePos {
  line : Int
  column : Int
  filename : Option[String]
}

/// Error categories.
enum ErrorKind {
  // Lexer phase
  LexerUnexpectedChar(Char)
  LexerUnclosedDelimiter(String)
  // Parser phase
  ParserUnexpectedToken(String, String)  // expected, got
  ParserUnclosedTag(String)
  ParserInvalidExpression(String)
  // Runtime / rendering phase
  UndefinedVariable(String)
  FilterNotFound(String)
  TemplateNotFound(String)
  TypeError(String, String)              // expected_type, actual_type
  InvalidFilterArgument(String)
  CircularExtends(String)
  // IO
  IoError(String)
}

/// The unified error type.
struct TemplateError {
  kind : ErrorKind
  pos : Option[SourcePos]
  message : String  // human-readable summary
}

/// Helper to format an error with source context.
fn show(self : TemplateError) -> String { ... }
```

### 4.4 Filter System

```moonbit
// src/filters.mbt

/// A filter function signature.
/// Takes the input value and an optional argument, returns a transformed value.
type FilterFn = (Value, Option[Value]) -> Result[Value, TemplateError]

/// Global filter registry (threaded through Context or held in a global table).
struct FilterRegistry {
  filters : Map[String, FilterFn]
}

/// Create a registry pre-populated with all built-in filters.
fn FilterRegistry::new() -> FilterRegistry { ... }

/// Register a custom filter.
fn FilterRegistry::register(self : FilterRegistry, name : String, f : FilterFn) -> Unit { ... }

/// Apply a named filter chain to a value.
fn apply_filters(
  value : Value,
  filters : Array[FilterCall],
  registry : FilterRegistry
) -> Result[Value, TemplateError]! { ... }
```

#### Built-in Filter Implementations

```moonbit
fn builtin_lower(val : Value, _arg : Option[Value]) -> Result[Value, TemplateError] {
  match val {
    String(s) -> Ok(Value::String(s.to_lower()))
    _ -> Err(TemplateError::type_error("String", val))
  }
}

fn builtin_default(val : Value, arg : Option[Value]) -> Result[Value, TemplateError] {
  match val {
    Nil -> match arg {
      Some(default) -> Ok(default)
      None -> Ok(Value::String(""))
    }
    String(s) if s == "" -> match arg {
      Some(default) -> Ok(default)
      None -> Ok(Value::String(""))
    }
    _ -> Ok(val)
  }
}
```

---

## 5. Rendering Flow

### 5.1 High-Level Pipeline

```
Source Text
    │
    ▼
┌─────────┐
│  Lexer  │   scan characters → produce Token stream
└────┬────┘
     │  Array[Token]
     ▼
┌─────────┐
│ Parser  │   recursive-descent → produce AST (Array[Stmt])
└────┬────┘
     │  Template { statements, blocks, macros, parent }
     ▼
┌──────────────┐
│  Renderer    │   walk AST, evaluate Expr nodes, emit strings
└──────┬───────┘
       │  String
       ▼
   Rendered Output
```

### 5.2 Lexer Phase

The lexer scans the template source character by character, producing a flat
`Array[Token]`.

```
Input:  "Hello {{ name | upper }}!"
Tokens: [Text("Hello "), VariableStart, Ident("name"),
         Pipe, Ident("upper"), VariableEnd, Text("!"), EOF]
```

**Algorithm outline:**

1. Maintain cursor `pos` and current `line` / `column`.
2. Loop while `pos < source.length()`:
   - If source starts with `{{` → emit `VariableStart`, enter **expression mode**.
   - If source starts with `{%` → emit `BlockStart`, enter **block mode**.
   - If source starts with `{#` → enter **comment mode** (skip until `#}`).
   - Otherwise → accumulate literal text until the next delimiter, emit `Text(chunk)`.
3. Inside expression/block mode, tokenise:
   - Identifiers (alphanumeric + `_`, starting with alpha/`_`)
   - String literals (`"..."` or `'...'`)
   - Numeric literals (integers and floats)
   - Operators and punctuation
   - Keywords (`if`, `for`, `in`, `and`, `or`, `not`, `true`, `false`, …)
4. Emit `EOF` at the end.

### 5.3 Parser Phase

A **recursive-descent** parser consumes the token stream and builds an AST.

**Grammar (simplified):**

```
template  = stmt*
stmt      = text | variable | comment | if_tag | for_tag | block_tag
          | extends_tag | include_tag | macro_tag | set_tag | raw_tag

variable  = VariableStart expr filter* VariableEnd
filter    = Pipe Ident (":" expr)?

if_tag    = BlockStart "if" expr BlockEnd stmt*
            (BlockStart "elif" expr BlockEnd stmt*)*
            (BlockStart "else" BlockEnd stmt*)?
            BlockStart "endif" BlockEnd

for_tag   = BlockStart "for" Ident ("," Ident)? "in" expr BlockEnd stmt*
            BlockStart "endfor" BlockEnd

block_tag = BlockStart "block" Ident BlockEnd stmt*
            BlockStart "endblock" BlockEnd
```

**Parsing strategy:**

1. The top-level parser repeatedly calls `parse_stmt()` until `EOF`.
2. Each `parse_*` function consumes tokens and returns the appropriate `Stmt` variant.
3. Expression parsing uses **Pratt parsing** (top-down operator precedence) to
   handle binary operators with correct precedence:

   | Precedence | Operators |
   |------------|-----------|
   | 1 (lowest) | `or` |
   | 2 | `and` |
   | 3 | `==` `!=` |
   | 4 | `<` `>` `<=` `>=` |
   | 5 | `+` `-` `~` |
   | 6 | `*` `/` `%` |
   | 7 | `not` `-` (unary prefix) |
   | 8 (highest) | `.` `[]` `()` `\|` (postfix) |

4. On parse error, produce `Err(TemplateError{ pos, kind: ParseError(...) })`.

### 5.4 Renderer Phase

The renderer walks the AST recursively and accumulates output into a
`StringBuilder` (MoonBit's `Buffer`).

```moonbit
fn render_stmts(
  stmts : Array[Stmt],
  ctx : Context,
  tpl : Template,
  loader : TemplateLoader
) -> Result[String, TemplateError]! {
  let buf = Buffer::new()
  for stmt in stmts {
    match stmt {
      Text(s) -> buf.write_string(s)
      Variable(expr) -> {
        let val = evaluate(expr, ctx)?
        let escaped = if ctx.auto_escape { html_escape(val.to_string()) } else { val.to_string() }
        buf.write_string(escaped)
      }
      If(cond, then_body, elifs, else_body) -> {
        if evaluate_bool(cond, ctx)? {
          buf.write_string(render_stmts(then_body, ctx, tpl, loader)?)
        } else {
          // try elifs in order
          var handled = false
          for (elif_cond, elif_body) in elifs {
            if evaluate_bool(elif_cond, ctx)? {
              buf.write_string(render_stmts(elif_body, ctx, tpl, loader)?)
              handled = true
              break
            }
          }
          if not(handled) {
            match else_body {
              Some(body) -> buf.write_string(render_stmts(body, ctx, tpl, loader)?)
              None -> ()
            }
          }
        }
      }
      For(var, key_var, iterable, body) -> {
        let val = evaluate(iterable, ctx)?
        match val {
          Array(items) -> {
            let len = items.length()
            for i = 0; i < len; i = i + 1 {
              ctx.push_scope()
              // Set loop variables
              let loop_val = Value::Map(Map::from_array([
                ("index", Value::Int((i + 1).to_int64())),
                ("index0", Value::Int(i.to_int64())),
                ("first", Value::Bool(i == 0)),
                ("last", Value::Bool(i == len - 1)),
                ("length", Value::Int(len.to_int64())),
              ]))
              ctx.set("loop", loop_val)
              ctx.set(var, items[i])
              buf.write_string(render_stmts(body, ctx, tpl, loader)?)
              ctx.pop_scope()
            }
          }
          Map(entries) -> {
            let keys = entries.keys()
            let len = keys.length()
            for i = 0; i < len; i = i + 1 {
              ctx.push_scope()
              let loop_val = Value::Map(Map::from_array([
                ("index", Value::Int((i + 1).to_int64())),
                ("index0", Value::Int(i.to_int64())),
                ("first", Value::Bool(i == 0)),
                ("last", Value::Bool(i == len - 1)),
                ("length", Value::Int(len.to_int64())),
              ]))
              ctx.set("loop", loop_val)
              match key_var {
                Some(kv) -> {
                  ctx.set(kv, Value::String(keys[i]))
                  ctx.set(var, entries[keys[i]])
                }
                None -> ctx.set(var, entries[keys[i]])
              }
              buf.write_string(render_stmts(body, ctx, tpl, loader)?)
              ctx.pop_scope()
            }
          }
          _ -> return Err(TemplateError::type_error("iterable", val))
        }
      }
      Block(name, body) -> {
        // Block content is already resolved during extends resolution
        buf.write_string(render_stmts(body, ctx, tpl, loader)?)
      }
      Include(name_expr) -> {
        let name_val = evaluate(name_expr, ctx)?
        match name_val {
          String(name) -> {
            let included = loader.load(name)?
            buf.write_string(included.render(ctx)?)
          }
          _ -> return Err(TemplateError::type_error("String", name_val))
        }
      }
      Macro(name, params, body) -> {
        // Store macro in context for later calls
        ctx.set(name, Value::Map(Map::from_array([
          ("params", Value::Array(params.map(fn(p) { Value::String(p) }))),
          ("body", /* serialized or reference */),
        ])))
      }
      Comment(_) -> ()  // nothing to emit
      Raw(s) -> buf.write_string(s)
      Set(var, expr) -> {
        let val = evaluate(expr, ctx)?
        ctx.set(var, val)
      }
      // Extends is handled at parse/load time, not render time
      Extends(_) -> ()  // already resolved
    }
  }
  Ok(buf.to_string())
}
```

### 5.5 Template Inheritance Resolution

Template inheritance is resolved **at load time**, before rendering:

```
1. Parse child template → child AST
2. If child has {% extends "parent" %}:
   a. Load & parse parent template → parent AST
   b. Collect child's top-level {% block %} bodies → child_blocks map
   c. Walk parent AST and replace each {% block name %}...{% endblock %}
      with child_blocks[name] if present, otherwise keep parent default
   d. The child's non-block content (outside blocks) is discarded
3. If no extends, use child AST as-is
```

### 5.6 Expression Evaluator

```moonbit
// src/evaluator.mbt

fn evaluate(expr : Expr, ctx : Context) -> Result[Value, TemplateError]! {
  match expr {
    Literal(v) -> Ok(v)
    Ident(name) -> match ctx.get(name) {
      Some(v) -> Ok(v)
      None -> Err(TemplateError::undefined_variable(name))
    }
    Unary(op, inner) -> {
      let v = evaluate(inner, ctx)?
      match (op, v) {
        (Neg, Int(n)) -> Ok(Value::Int(-n))
        (Neg, Float(f)) -> Ok(Value::Float(-f))
        (Not, Bool(b)) -> Ok(Value::Bool(not(b)))
        (Not, Nil) -> Ok(Value::Bool(true))  // nil is falsy
        (Not, _) -> Ok(Value::Bool(false))   // truthy → false
        _ -> Err(TemplateError::type_error("numeric/boolean", v))
      }
    }
    Binary(lhs, op, rhs) -> {
      let l = evaluate(lhs, ctx)?
      let r = evaluate(rhs, ctx)?
      eval_binary(l, op, r)
    }
    Member(obj, key) -> {
      let o = evaluate(obj, ctx)?
      match o {
        Map(m) -> match m[key] {
          Some(v) -> Ok(v)
          None -> Err(TemplateError::undefined_variable(key))
        }
        _ -> Err(TemplateError::type_error("object", o))
      }
    }
    Index(obj, idx) -> {
      let o = evaluate(obj, ctx)?
      let i = evaluate(idx, ctx)?
      match (o, i) {
        (Array(arr), Int(n)) -> {
          if n >= 0 && n < arr.length().to_int64() {
            Ok(arr[n.to_int()])
          } else {
            Err(TemplateError::new("index out of bounds"))
          }
        }
        (Map(m), String(k)) -> match m[k] {
          Some(v) -> Ok(v)
          None -> Ok(Value::Nil)
        }
        (String(s), Int(n)) -> {
          if n >= 0 && n < s.length().to_int64() {
            Ok(Value::String(s[n.to_int()].to_string()))
          } else {
            Err(TemplateError::new("index out of bounds"))
          }
        }
        _ -> Err(TemplateError::type_error("indexable", o))
      }
    }
    Filter(inner, filters) -> {
      let v = evaluate(inner, ctx)?
      apply_filters(v, filters, ctx.filter_registry)
    }
    Test(test_name, inner) -> {
      let v = evaluate(inner, ctx)?
      match test_name {
        "defined" -> Ok(Value::Bool(v is not Nil))
        "odd" -> match v {
          Int(n) -> Ok(Value::Bool(n % 2 != 0))
          _ -> Err(TemplateError::type_error("Int", v))
        }
        "even" -> match v {
          Int(n) -> Ok(Value::Bool(n % 2 == 0))
          _ -> Err(TemplateError::type_error("Int", v))
        }
        _ -> Err(TemplateError::new("unknown test: \{test_name}"))
      }
    }
    Call(name, args) -> {
      // Look up macro, evaluate with bound parameters
      match ctx.get(name) {
        Some(Value::Map(m)) if m.contains("params") && m.contains("body") -> {
          // Execute macro with args bound to params
          ctx.push_scope()
          let params = match m["params"] {
            Some(Value::Array(a)) -> a
            _ -> return Err(TemplateError::new("invalid macro definition"))
          }
          for i = 0; i < params.length(); i = i + 1 {
            let pname = match params[i] {
              Value::String(s) -> s
              _ -> continue
            }
            let pval = if i < args.length() {
              evaluate(args[i], ctx)?
            } else {
              Value::Nil
            }
            ctx.set(pname, pval)
          }
          // Render macro body
          let body = ... // deserialize body
          let result = render_stmts(body, ctx, ...)?
          ctx.pop_scope()
          Ok(Value::String(result))
        }
        _ -> Err(TemplateError::new("unknown function: \{name}"))
      }
    }
    Concat(lhs, rhs) -> {
      let l = evaluate(lhs, ctx)?
      let r = evaluate(rhs, ctx)?
      Ok(Value::String(l.to_string() + r.to_string()))
    }
  }
}
```

### 5.7 Truthiness

In conditionals, the following values are **falsy**; everything else is truthy:

- `Nil`
- `Bool(false)`
- `String("")` (empty string)
- `Int(0)`
- `Float(0.0)`
- `Array([])` (empty array)
- `Map({})` (empty map)

### 5.8 Template Loader

Resolution of `{% extends %}` and `{% include %}` requires a **template loader** —
a user-provided function that maps a template name to its source text.

```moonbit
// src/lib.mbt

/// A function that loads a template by name.
/// Returns the source text, or an error if not found.
type TemplateLoader = (String) -> Result[String, TemplateError]
```

Example: loading from the filesystem or an in-memory map:

```moonbit
// Simple in-memory loader
let templates = Map::from_array([
  ("base.html", "<html>{% block body %}{% endblock %}</html>"),
  ("index.html", "{% extends \"base.html\" %}{% block body %}Hello{% endblock %}"),
])

let loader = fn(name : String) -> Result[String, TemplateError] {
  match templates[name] {
    Some(src) -> Ok(src)
    None -> Err(TemplateError::template_not_found(name))
  }
}
```

---

## 6. Project Directory Layout

```
MoonTera/
├── moon.mod                  # module metadata
├── moon.pkg                  # root package config (imports src sub-package)
├── MoonTera.mbt              # root library entry (re-exports from src/)
│
├── src/                      # core implementation (sub-package)
│   ├── moon.pkg              # sub-package config
│   ├── lib.mbt               # Template struct, parse(), render(), TemplateLoader
│   ├── errors.mbt            # ErrorKind, SourcePos, TemplateError
│   ├── lexer.mbt             # Token enum, lex() function
│   ├── ast.mbt               # BinOp, UnaryOp, Value, FilterCall, Expr, Stmt
│   ├── parser.mbt            # parse() → Array[Stmt]
│   ├── evaluator.mbt         # evaluate() → Value
│   ├── renderer.mbt          # render_stmts() → String
│   ├── context.mbt           # Scope, Context
│   └── filters.mbt           # FilterRegistry, built-in filters
│
├── cmd/
│   └── main/
│       ├── moon.pkg          # is-main: true
│       └── main.mbt          # CLI entry point
│
├── MoonTera_test.mbt         # black-box tests
├── MoonTera_wbtest.mbt       # white-box tests
│
├── docs/
│   └── architecture.md       # this document
│
├── README.md
├── README.mbt.md
└── .gitignore
```

### Package Configuration (`moon.pkg` files)

**Root `moon.pkg`:**
```json
import {
  "moonbitlang/core" @core,
  "lin2077-zeming/MoonTera/src" @src,
}
```

**`src/moon.pkg`:**
```json
import {
  "moonbitlang/core" @core,
}
```

**`cmd/main/moon.pkg`:**
```json
import {
  "lin2077-zeming/MoonTera/src" @src,
}
options(
  "is-main": true,
)
```

---

## Appendix A: Comparison with Tera & Jinja2

| Feature | MoonTera | Tera (Rust) | Jinja2 (Python) |
|---------|----------|-------------|-----------------|
| Variables | `{{ x }}` | `{{ x }}` | `{{ x }}` |
| Filters | `{{ x \| f }}` | `{{ x \| f }}` | `{{ x \| f }}` |
| Comments | `{# ... #}` | `{# ... #}` | `{# ... #}` |
| Conditionals | `{% if %}` | `{% if %}` | `{% if %}` |
| Loops | `{% for %}` | `{% for %}` | `{% for %}` |
| Inheritance | `{% extends %}` | `{% extends %}` | `{% extends %}` |
| Macros | `{% macro %}` | `{% macro %}` | `{% macro %}` |
| Includes | `{% include %}` | `{% include %}` | `{% include %}` |
| Super | `{{ super() }}` | `{{ super() }}` | `{{ super() }}` |
| Raw | `{% raw %}` | `{% raw %}` | `{% raw %}` |

---

## Appendix B: Open Design Questions

These are deferred decisions to be resolved during implementation:

1. **Auto-escaping** — should it be on by default? Tera does it; Jinja2 can
   be configured. For an HTML-oriented engine, default-on is safer.
2. **Sandbox / security** — should we restrict what expressions can do?
   (file I/O, infinite loops, …)
3. **Custom delimiters** — should users be able to change `{{`/`{%`/`{#`?
4. **Async rendering** — MoonBit has no async runtime; all rendering is
   synchronous.
5. **Error recovery** — should the parser attempt error recovery (produce
   partial AST + warnings) or fail-fast?
