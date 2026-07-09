# MoonTera — A Jinja2/Tera-inspired Template Engine for MoonBit

**MoonTera** is a fast, safe, and easy-to-use template rendering engine for
[MoonBit](https://www.moonbitlang.com/), inspired by
[Jinja2](https://jinja.palletsprojects.com/) and
[Tera](https://keats.github.io/tera/).

```jinja2
{% extends "layout.html" %}

{% block title %}Welcome{% endblock %}

{% block content %}
  <h1>Hello, {{ user.name | upper }}!</h1>
  <ul>
  {% for item in user.items %}
    <li>{{ loop.index }}. {{ item | escape }}</li>
  {% endfor %}
  </ul>
{% endblock %}
```

## Features

- **Variables** — `{{ user.name }}` with dot access and index access
- **Filters** — `{{ name | upper | trim }}` with 13 built-in filters
- **Conditionals** — `{% if %}`, `{% elif %}`, `{% else %}`, `{% endif %}`
- **Loops** — `{% for x in items %}...{% endfor %}` with `loop.index`, `loop.first`, etc.
- **Macros** — `{% macro button(text, class) %}...{% endmacro %}`
- **Includes** — `{% include "partial.html" %}`
- **Inheritance** — `{% extends %}`, `{% block %}`, `{% endblock %}` (planned)
- **Auto-escaping** — Safe against XSS by default (planned)
- **Zero dependencies** — Uses only `moonbitlang/core`

## Quick Start

### Installation

```bash
moon add linzeming/template
```

### Hello World

```moonbit
let tpl = @template.Template::parse("Hello, {{ name }}!")?
let ctx = @template.Context::new()
  .set("name", @template.Value::Str("MoonBit"))
let result = tpl.render(ctx)?
println(result) // "Hello, MoonBit!"
```

### Complete Example

```moonbit
fn main {
  // 1. Parse the template
  let source = #|
    <h1>{{ title }}</h1>
    {% if items | length > 0 %}
      <ul>
      {% for item in items %}
        <li>{{ loop.index }}. {{ item }}</li>
      {% endfor %}
      </ul>
    {% else %}
      <p>No items found.</p>
    {% endif %}
  |#
  let tpl = @template.Template::parse(source)?

  // 2. Build the context
  let ctx = @template.Context::new()
    .set("title", @template.Value::Str("Shopping List"))
    .set("items", @template.Value::Array([
      @template.Value::Str("Apples"),
      @template.Value::Str("Bananas"),
      @template.Value::Str("Oranges"),
    ]))

  // 3. Render
  let html = tpl.render(ctx)?
  println(html)
}
```

## Syntax Guide

### Variables

Output variables with `{{ }}`:

```jinja2
{{ username }}
{{ user.name }}           {# dot access #}
{{ items[0] }}            {# index access #}
{{ a + b }}               {# arithmetic #}
{{ user.name | upper }}   {# with filter #}
```

### Filters

Apply filters with the pipe operator `|`:

```jinja2
{{ name | upper }}                  {# "hello" → "HELLO" #}
{{ name | trim | capitalize }}      {# chain filters #}
{{ items | join(", ") }}            {# with arguments #}
{{ value | default("N/A") }}        {# default value #}
```

### Conditionals

```jinja2
{% if user.is_admin %}
  <a href="/admin">Admin Panel</a>
{% elif user.is_moderator %}
  <span>Moderator</span>
{% else %}
  <span>Regular User</span>
{% endif %}
```

### Loops

```jinja2
{% for item in items %}
  <li>{{ loop.index }}. {{ item }}</li>
{% endfor %}
```

**`loop` builtin variables:**

| Variable | Description |
|----------|-------------|
| `loop.index`  | 1-based iteration counter |
| `loop.index0` | 0-based iteration counter |
| `loop.first`  | `true` on the first iteration |
| `loop.last`   | `true` on the last iteration |
| `loop.length` | total number of items |

### Macros

Define reusable template fragments:

```jinja2
{% macro input(name, type="text", value="") %}
  <input type="{{ type }}" name="{{ name }}" value="{{ value }}">
{% endmacro %}

{{ input("username") }}
{{ input("password", type="password") }}
```

### Includes

Include another template:

```jinja2
{% include "header.html" %}
<main>content</main>
{% include "footer.html" %}
```

Templates are loaded via `TemplateLoader`:

```moonbit
let loader = @template.TemplateLoader::new()
  .add("header", "<header>{{ title }}</header>")
  .add("footer", "<footer>© 2026</footer>")
let result = tpl.render_with_loader(ctx, loader)?
```

### Template Inheritance (planned)

```jinja2
{# base.html #}
<html>
<head><title>{% block title %}Default{% endblock %}</title></head>
<body>{% block body %}{% endblock %}</body>
</html>

{# page.html #}
{% extends "base.html" %}
{% block title %}My Page{% endblock %}
{% block body %}<p>Hello!</p>{% endblock %}
```

### Comments

```jinja2
{# This is a comment and will not appear in the output #}
```

## Built-in Filters

| Filter | Description | Example |
|--------|-------------|---------|
| `upper` | Uppercase string | `"hello"` → `"HELLO"` |
| `lower` | Lowercase string | `"HELLO"` → `"hello"` |
| `capitalize` | Capitalize first character | `"hello"` → `"Hello"` |
| `trim` | Remove leading/trailing whitespace | `" hi "` → `"hi"` |
| `length` | Length of string/array/object | `"abc"` → `3` |
| `reverse` | Reverse string or array | `"abc"` → `"cba"` |
| `first` | First character/element | `"abc"` → `"a"` |
| `last` | Last character/element | `"abc"` → `"c"` |
| `join(sep)` | Join array with separator | `[a,b]` → `"a,b"` |
| `replace(from, to)` | Replace substrings | `"hi"|replace("i","ey")` → `"hey"` |
| `default(val)` | Fallback if value is falsy | `""|default("N/A")` → `"N/A"` |
| `int` | Convert to integer | `"42"|int` → `42` |
| `string` | Convert to string | `42|string` → `"42"` |

### Custom Filters

```moonbit
let filters = @template.FilterRegistry::default()
  .register("greet", fn(value, _args) {
    match value {
      @template.Value::Str(s) => Ok(@template.Value::Str("Hello, " + s + "!"))
      _ => Err("greet: expected string")
    }
  })
```

## API Reference

### `Template`

| Method | Signature | Description |
|--------|-----------|-------------|
| `parse` | `(source: String) → Result[Template, TemplateError]` | Compile source to template |
| `render` | `(ctx: Context) → Result[String, TemplateError]` | Render with context |
| `render_with_loader` | `(ctx: Context, loader: TemplateLoader) → Result[String, TemplateError]` | Render with includes |

### `Context`

| Method | Description |
|--------|-------------|
| `new()` | Create empty root context |
| `new_child(parent)` | Create nested scope |
| `set(name, value)` | Set variable in current scope |
| `get(name)` | Look up variable (walks scope chain) |
| `register_macro(MacroDef)` | Register a macro definition |

### `Value`

| Variant | Type |
|---------|------|
| `Null` | null |
| `Bool(Bool)` | boolean |
| `Int(Int64)` | integer |
| `Float(Double)` | float |
| `Str(String)` | string |
| `Array(Array[Value])` | array |
| `Object(Map[String, Value])` | object (for member access) |

### `TemplateError`

Unified error type with source location:

```moonbit
match Template::parse(source) {
  Ok(t) => ...
  Err(err) => {
    println(err.to_string())
    // Error: SyntaxError in template "<source>" at line 3, column 8
    //   expected '}}'
  }
}
```

## Project Structure

```
src/
├── lib.mbt          # Public API entry point
├── ast.mbt          # AST node types (Value, Expr, Node, ...)
├── lexer.mbt        # Template source → Tokens
├── parser.mbt       # Tokens → AST (Pratt expression parser)
├── evaluator.mbt    # Expression evaluation
├── renderer.mbt     # AST → output string
├── template.mbt     # Top-level parse + render
├── context.mbt      # Nested-scope variable storage
├── filters.mbt      # Built-in filter functions
├── loader.mbt       # Include template resolver
└── errors.mbt       # Unified error types
```

## Examples

See the [`examples/`](examples/) directory:

- [`hello.mbt`](examples/hello.mbt) — Minimal Hello World
- [`blog.mbt`](examples/blog.mbt) — Blog page with loops and conditionals
- [`email.mbt`](examples/email.mbt) — Email template with macros and includes

## Development

### Running Tests

```bash
moon test
```

### Project Status

| Feature | Status |
|---------|--------|
| Variables & expressions | ✅ |
| Filters (13 built-in) | ✅ |
| Conditionals (if/elif/else) | ✅ |
| For loops with loop.* | ✅ |
| Macros | ✅ |
| Include | ✅ |
| Template inheritance | 🚧 Planned |
| Auto-escaping | 🚧 Planned |
| Custom filters | ✅ |

## License

MIT License. See [LICENSE](LICENSE) for details.
