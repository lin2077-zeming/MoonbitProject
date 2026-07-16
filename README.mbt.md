# MoonTera — A MoonBit Template Engine

MoonTera is a [MoonBit](https://www.moonbitlang.com/) template rendering engine inspired by
[Jinja2](https://jinja.palletsprojects.com/) (Python) and
[Tera](https://keats.github.io/tera/) (Rust).
It compiles templates into an AST and renders them with a context—fast, safe, and extensible.

## Features

- **Variable output** — `{{ name }}`, `{{ user.profile.email }}`
- **13 built-in filters** — `upper`, `lower`, `trim`, `length`, `join`, `replace`, `default`, …
- **Chained filters** — `{{ text | trim | upper }}`
- **Conditionals** — `{% if %}`, `{% elif %}`, `{% else %}`, `{% endif %}`
- **For loops** — `{% for item in list %}` with `loop.index`, `loop.first`, `loop.last`
- **Template inheritance** — `{% extends %}`, `{% block %}`
- **Macros** — `{% macro name(args) %}...{% endmacro %}`, `{{ name(...) }}`
- **Includes** — `{% include "partial.html" %}`
- **Unified error types** — with source location tracking
- **Zero dependencies** — pure MoonBit, no external packages

## Quick Start

### Installation

```bash
moon add lin2077-zeming/MoonTera
```

### Hello World

```moonbit
fn main {
  let tpl = Template::parse("hello", "Hello {{ name }}!")!
  let ctx = Context::new()
  ctx.set("name", Value::Str("MoonBit"))
  let result = tpl.render(ctx)!
  println(result)  // "Hello MoonBit!"
}
```

### Using TemplateLoader (with inheritance)

```moonbit
fn main {
  let loader = TemplateLoader::new()

  loader = loader.add_template("layout.html",
    "<html><body>{% block body %}Default{% endblock %}</body></html>"
  )!

  loader = loader.add_template("page.html",
    "{% extends \"layout.html\" %}{% block body %}<p>Hello {{ user }}!</p>{% endblock %}"
  )!

  let ctx = Context::new()
  ctx.set("user", Value::Str("World"))
  println(loader.render("page.html", ctx)!)  // "<html><body><p>Hello World!</p></body></html>"
}
```

## Syntax Guide

### Variable Output

```
{{ username }}
{{ user.name }}
{{ items[0] }}
{{ "literal" }}
{{ 42 }}
{{ true }}
```

### Filters

Filters transform values with the `|` operator. Chain multiple filters left-to-right.

```
{{ name | upper }}
{{ text | trim | upper }}
{{ value | default:"N/A" }}
{{ items | join:", " }}
```

### Conditionals

```
{% if user.role == "admin" %}
  Admin panel
{% elif user.role == "moderator" %}
  Mod tools
{% else %}
  Guest view
{% endif %}
```

### For Loops

```
{% for item in items %}
  {{ loop.index }}. {{ item }}
{% endfor %}
```

Loop variables: `loop.index` (1-based), `loop.index0` (0-based), `loop.first`, `loop.last`, `loop.length`.

### Template Inheritance

**Base** (`layout.html`):
```html
<html>
<head><title>{% block title %}Default{% endblock %}</title></head>
<body>{% block body %}{% endblock %}</body>
</html>
```

**Child**:
```
{% extends "layout.html" %}
{% block title %}Home{% endblock %}
{% block body %}<p>Welcome!</p>{% endblock %}
```

### Macros

```
{% macro input(name, type) %}
  <input type="{{ type }}" name="{{ name }}">
{% endmacro %}

{{ input("username", "text") }}
```

### Includes

```
{% include "header.html" %}
```

The included template shares the current context.

### Comments

```
{# single-line #}
{# multi-line comment #}
```

## Built-in Filters

| Filter | Args | Description | Example |
|--------|------|-------------|---------|
| `upper` | — | Uppercase | `"hi"` → `"HI"` |
| `lower` | — | Lowercase | `"HI"` → `"hi"` |
| `capitalize` | — | First letter upper | `"hi"` → `"Hi"` |
| `trim` | — | Strip whitespace | `" hi "` → `"hi"` |
| `length` | — | String/array length | `"abc"` → `3` |
| `reverse` | — | Reverse | `"abc"` → `"cba"` |
| `first` | — | First char/element | `"hi"` → `"h"` |
| `last` | — | Last char/element | `"hi"` → `"i"` |
| `join` | `sep` | Join array | `[a,b]` → `"a,b"` |
| `replace` | `from,to` | Replace all | `"aba"` → `"axa"` |
| `default` | `val` | Fallback if empty | `""` → `"N/A"` |
| `int` | — | Convert to int | `"42"` → `42` |
| `string` | — | Convert to string | `42` → `"42"` |

## API Reference

### Template

```moonbit
pub fn Template::parse(name: String, source: String) -> Result[Template, TemplateError]
pub fn render(self: Template, ctx: Context) -> Result[String, TemplateError]
```

### TemplateLoader

```moonbit
pub fn TemplateLoader::new() -> TemplateLoader
pub fn add_template(self, name: String, source: String) -> Result[TemplateLoader, TemplateError]
pub fn render(self, name: String, ctx: Context) -> Result[String, TemplateError]
```

### Context

```moonbit
pub fn Context::new() -> Context
pub fn Context::new_child(parent: Context) -> Context
pub fn get(self, name: String) -> Option[Value]
pub fn set(self, name: String, value: Value) -> Unit
```

### Value

```moonbit
pub enum Value {
  Null
  Bool(Bool)
  Int(Int64)
  Float(Double)
  Str(String)
  Array(Array[Value])
  Object(Map[String, Value])
}
```

## Project Structure

```
src/
├── lexer.mbt          # Lexer: source → tokens
├── ast.mbt            # AST: Value, Expr, Node
├── parser.mbt         # Parser: tokens → AST (Pratt)
├── evaluator.mbt      # Evaluator: Expr + Context → Value
├── renderer.mbt       # Renderer: Node[] + Context → String
├── context.mbt        # Context: nested scopes
├── filters.mbt        # 13 built-in filters
├── loader.mbt         # TemplateLoader
├── template.mbt       # Template::parse / render
├── errors.mbt         # Unified error types
└── lib.mbt            # Public API
```

## Development

```bash
moon test   # 198 tests covering all modules
```

## License

MIT — see [LICENSE](LICENSE)
