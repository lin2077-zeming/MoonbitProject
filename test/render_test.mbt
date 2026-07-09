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
// 5. Block tags are skipped (not yet implemented)
// =============================================================================

test "render with skipped if block" {
  // {% if ... %} blocks are skipped by the parser for now.
  let ctx = @tpl.Context::new().set("x", @tpl.Value::Bool(true))
  let result = render_with("before{% if x %}inside{% endif %}after", ctx)
  // Block tags and their content are skipped entirely.
  @prelude.assert_eq!(result, "beforeafter")
}

test "render with skipped for block" {
  let ctx = @tpl.Context::new()
  let result = render_with("start{% for x in items %}{{ x }}{% endfor %}end", ctx)
  @prelude.assert_eq!(result, "startend")
}
