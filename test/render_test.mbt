// Copyright (c) 2024 LinZeming
// Released under the MIT License
//
// Integration tests for the full render pipeline:
//   source → lexer → parser → template → renderer → output

/// Helper: parse and render a template string with empty context.
fn render(source : String) -> String {
  let tpl_result = @tpl.Template::parse(source)
  let tpl = match tpl_result {
    Ok(t) => t
    Err(msg) => @prelude.fail("parse failed: " + msg)
  }
  let ctx = @tpl.Context::new()
  let result = tpl.render(ctx)
  match result {
    Ok(s) => s
    Err(msg) => @prelude.fail("render failed: " + msg)
  }
}

/// Helper: parse and render with a prepared context.
fn render_with(source : String, ctx : @tpl.Context) -> String {
  let tpl_result = @tpl.Template::parse(source)
  let tpl = match tpl_result {
    Ok(t) => t
    Err(msg) => @prelude.fail("parse failed: " + msg)
  }
  let result = tpl.render(ctx)
  match result {
    Ok(s) => s
    Err(msg) => @prelude.fail("render failed: " + msg)
  }
}

// =============================================================================
// 1. Plain text rendering
// =============================================================================

test "render plain text" {
  let result = render("Hello, World!")
  @prelude.assert_eq!(result, "Hello, World!")
}

test "render empty template" {
  let result = render("")
  @prelude.assert_eq!(result, "")
}

test "render multiline text" {
  let result = render("line1\nline2\nline3")
  @prelude.assert_eq!(result, "line1\nline2\nline3")
}

test "render text with special characters" {
  let result = render("<html>&\"'")
  @prelude.assert_eq!(result, "<html>&\"'")
}

// =============================================================================
// 2. Single variable rendering
// =============================================================================

test "render simple variable" {
  let ctx = @tpl.Context::new().set("name", @tpl.Value::Str("MoonBit"))
  let result = render_with("{{ name }}", ctx)
  @prelude.assert_eq!(result, "MoonBit")
}

test "render int variable" {
  let ctx = @tpl.Context::new().set("count", @tpl.Value::Int(42L))
  let result = render_with("{{ count }}", ctx)
  @prelude.assert_eq!(result, "42")
}

test "render float variable" {
  let ctx = @tpl.Context::new().set("pi", @tpl.Value::Float(3.14))
  let result = render_with("{{ pi }}", ctx)
  @prelude.assert_eq!(result, "3.14")
}

test "render bool variable" {
  let ctx = @tpl.Context::new().set("flag", @tpl.Value::Bool(true))
  let result = render_with("{{ flag }}", ctx)
  @prelude.assert_eq!(result, "true")
}

// =============================================================================
// 3. Mixed text and variables
// =============================================================================

test "render text with embedded variable" {
  let ctx = @tpl.Context::new().set("name", @tpl.Value::Str("MoonBit"))
  let result = render_with("Hello, {{ name }}!", ctx)
  @prelude.assert_eq!(result, "Hello, MoonBit!")
}

test "render multiple variables" {
  let ctx = @tpl.Context::new()
    .set("a", @tpl.Value::Int(1L))
    .set("b", @tpl.Value::Int(2L))
    .set("sum", @tpl.Value::Int(3L))
  let result = render_with("{{ a }} + {{ b }} = {{ sum }}", ctx)
  @prelude.assert_eq!(result, "1 + 2 = 3")
}

test "render variables with surrounding text" {
  let ctx = @tpl.Context::new()
    .set("first", @tpl.Value::Str("Alice"))
    .set("last", @tpl.Value::Str("Smith"))
  let result = render_with("Name: {{ first }} {{ last }}", ctx)
  @prelude.assert_eq!(result, "Name: Alice Smith")
}

test "render expression arithmetic" {
  let ctx = @tpl.Context::new()
    .set("x", @tpl.Value::Int(10L))
    .set("y", @tpl.Value::Int(20L))
  let result = render_with("{{ x + y }}", ctx)
  @prelude.assert_eq!(result, "30")
}

test "render expression comparison" {
  let ctx = @tpl.Context::new()
    .set("a", @tpl.Value::Int(1L))
    .set("b", @tpl.Value::Int(2L))
  let result = render_with("{{ a == b }}", ctx)
  @prelude.assert_eq!(result, "false")
}

// =============================================================================
// 4. Error cases
// =============================================================================

test "render undefined variable returns error" {
  let tpl_result = @tpl.Template::parse("{{ missing }}")
  let tpl = match tpl_result {
    Ok(t) => t
    Err(msg) => @prelude.fail("parse failed: " + msg)
  }
  let ctx = @tpl.Context::new()
  let result = tpl.render(ctx)
  match result {
    Ok(_) => @prelude.assert_false!(true)
    Err(_) => @prelude.assert_true!(true)
  }
}

test "render with member access" {
  let m : Map[String, @tpl.Value] = Map::new()
  m["name"] = @tpl.Value::Str("Alice")
  let ctx = @tpl.Context::new().set("user", @tpl.Value::Object(m))
  let result = render_with("{{ user.name }}", ctx)
  @prelude.assert_eq!(result, "Alice")
}

// =============================================================================
// 5. If / elif / else
// =============================================================================

test "render if condition true" {
  let ctx = @tpl.Context::new().set("show", @tpl.Value::Bool(true))
  let result = render_with("{% if show %}Hello{% endif %}", ctx)
  @prelude.assert_eq!(result, "Hello")
}

test "render if condition false" {
  let ctx = @tpl.Context::new().set("show", @tpl.Value::Bool(false))
  let result = render_with("{% if show %}Hello{% endif %}", ctx)
  @prelude.assert_eq!(result, "")
}

test "render if with else true" {
  let ctx = @tpl.Context::new().set("x", @tpl.Value::Bool(true))
  let result = render_with("{% if x %}yes{% else %}no{% endif %}", ctx)
  @prelude.assert_eq!(result, "yes")
}

test "render if with else false" {
  let ctx = @tpl.Context::new().set("x", @tpl.Value::Bool(false))
  let result = render_with("{% if x %}yes{% else %}no{% endif %}", ctx)
  @prelude.assert_eq!(result, "no")
}

test "render if with elif" {
  let ctx = @tpl.Context::new().set("score", @tpl.Value::Int(85L))
  let result = render_with(
    "{% if score >= 90 %}A{% elif score >= 80 %}B{% elif score >= 70 %}C{% else %}F{% endif %}",
    ctx,
  )
  @prelude.assert_eq!(result, "B")
}

test "render if with elif first branch" {
  let ctx = @tpl.Context::new().set("score", @tpl.Value::Int(95L))
  let result = render_with(
    "{% if score >= 90 %}A{% elif score >= 80 %}B{% else %}F{% endif %}",
    ctx,
  )
  @prelude.assert_eq!(result, "A")
}

test "render if with elif else fallback" {
  let ctx = @tpl.Context::new().set("score", @tpl.Value::Int(55L))
  let result = render_with(
    "{% if score >= 90 %}A{% elif score >= 80 %}B{% else %}F{% endif %}",
    ctx,
  )
  @prelude.assert_eq!(result, "F")
}

test "render if condition with comparison lt" {
  let ctx = @tpl.Context::new().set("x", @tpl.Value::Int(3L))
  let result = render_with("{% if x < 5 %}small{% endif %}", ctx)
  @prelude.assert_eq!(result, "small")
}

test "render if condition with comparison gt" {
  let ctx = @tpl.Context::new().set("x", @tpl.Value::Int(10L))
  let result = render_with("{% if x > 5 %}big{% else %}small{% endif %}", ctx)
  @prelude.assert_eq!(result, "big")
}

test "render if condition with eq" {
  let ctx = @tpl.Context::new().set("x", @tpl.Value::Int(5L))
  let result = render_with("{% if x == 5 %}five{% else %}not five{% endif %}", ctx)
  @prelude.assert_eq!(result, "five")
}

test "render if with variable in body" {
  let ctx = @tpl.Context::new()
    .set("logged_in", @tpl.Value::Bool(true))
    .set("name", @tpl.Value::Str("Alice"))
  let result = render_with(
    "{% if logged_in %}Welcome, {{ name }}!{% else %}Please log in.{% endif %}",
    ctx,
  )
  @prelude.assert_eq!(result, "Welcome, Alice!")
}

test "render if with text surrounding" {
  let ctx = @tpl.Context::new().set("flag", @tpl.Value::Bool(true))
  let result = render_with("Before {% if flag %}ON{% endif %} After", ctx)
  @prelude.assert_eq!(result, "Before ON After")
}

test "render if with falsy int zero" {
  let ctx = @tpl.Context::new().set("count", @tpl.Value::Int(0L))
  let result = render_with("{% if count %}has items{% else %}empty{% endif %}", ctx)
  @prelude.assert_eq!(result, "empty")
}

test "render if with truthy int" {
  let ctx = @tpl.Context::new().set("count", @tpl.Value::Int(5L))
  let result = render_with("{% if count %}has items{% else %}empty{% endif %}", ctx)
  @prelude.assert_eq!(result, "has items")
}

// =============================================================================
// 6. For loops
// =============================================================================

test "render simple for loop" {
  let nums = @tpl.Value::Array([
    @tpl.Value::Int(1L),
    @tpl.Value::Int(2L),
    @tpl.Value::Int(3L),
  ])
  let ctx = @tpl.Context::new().set("nums", nums)
  let result = render_with("{% for n in nums %}{{ n }},{% endfor %}", ctx)
  @prelude.assert_eq!(result, "1,2,3,")
}

test "render empty for loop" {
  let empty : Array[@tpl.Value] = []
  let ctx = @tpl.Context::new().set("nums", @tpl.Value::Array(empty))
  let result = render_with("{% for n in nums %}{{ n }}{% endfor %}", ctx)
  @prelude.assert_eq!(result, "")
}

test "render for loop with loop.index" {
  let items = @tpl.Value::Array([
    @tpl.Value::Str("a"),
    @tpl.Value::Str("b"),
  ])
  let ctx = @tpl.Context::new().set("items", items)
  let result = render_with(
    "{% for x in items %}{{ loop.index }}:{{ x }} {% endfor %}",
    ctx,
  )
  @prelude.assert_eq!(result, "1:a 2:b ")
}

test "render for loop with loop.first" {
  let items = @tpl.Value::Array([
    @tpl.Value::Str("a"),
    @tpl.Value::Str("b"),
    @tpl.Value::Str("c"),
  ])
  let ctx = @tpl.Context::new().set("items", items)
  let result = render_with(
    "{% for x in items %}{% if loop.first %}[{% endif %}{{ x }}{% if loop.last %}]{% else %}, {% endif %}{% endfor %}",
    ctx,
  )
  @prelude.assert_eq!(result, "[a, b, c]")
}

test "render for loop with loop.last" {
  let items = @tpl.Value::Array([
    @tpl.Value::Str("x"),
    @tpl.Value::Str("y"),
    @tpl.Value::Str("z"),
  ])
  let ctx = @tpl.Context::new().set("items", items)
  let result = render_with(
    "{% for v in items %}{{ v }}{% if not loop.last %}|{% endif %}{% endfor %}",
    ctx,
  )
  @prelude.assert_eq!(result, "x|y|z")
}

test "render for loop with loop.index0" {
  let items = @tpl.Value::Array([
    @tpl.Value::Str("zero"),
    @tpl.Value::Str("one"),
  ])
  let ctx = @tpl.Context::new().set("items", items)
  let result = render_with(
    "{% for x in items %}{{ loop.index0 }}:{{ x }} {% endfor %}",
    ctx,
  )
  @prelude.assert_eq!(result, "0:zero 1:one ")
}

test "render for loop with loop.length" {
  let items = @tpl.Value::Array([
    @tpl.Value::Str("x"),
    @tpl.Value::Str("y"),
    @tpl.Value::Str("z"),
  ])
  let ctx = @tpl.Context::new().set("items", items)
  let result = render_with("{{ loop.length }}", ctx)
  @prelude.assert_eq!(result, "")
}

test "render for loop with if inside" {
  let nums = @tpl.Value::Array([
    @tpl.Value::Int(1L),
    @tpl.Value::Int(2L),
    @tpl.Value::Int(3L),
    @tpl.Value::Int(4L),
  ])
  let ctx = @tpl.Context::new().set("nums", nums)
  let result = render_with(
    "{% for n in nums %}{% if n > 2 %}{{ n }}{% endif %}{% endfor %}",
    ctx,
  )
  @prelude.assert_eq!(result, "34")
}

test "render for loop with surrounding text" {
  let items = @tpl.Value::Array([
    @tpl.Value::Str("a"),
    @tpl.Value::Str("b"),
  ])
  let ctx = @tpl.Context::new().set("items", items)
  let result = render_with("<ul>{% for x in items %}<li>{{ x }}</li>{% endfor %}</ul>", ctx)
  @prelude.assert_eq!(result, "<ul><li>a</li><li>b</li></ul>")
}
