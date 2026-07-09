// Copyright (c) 2024 LinZeming
// Released under the MIT License
//
// Black-box tests for filter system and built-in filters.

/// Helper: render a template string with the given context.
fn render_with(source : String, ctx : @tpl.Context) -> String {
  let tpl_result = @tpl.Template::parse(source)
  let tpl = match tpl_result {
    Ok(t) => t
    Err(msg) => @prelude.fail("parse failed: " + msg)
  }
  match tpl.render(ctx) {
    Ok(s) => s
    Err(msg) => @prelude.fail("render failed: " + msg)
  }
}

// =============================================================================
// 1. Single filters
// =============================================================================

test "filter upper" {
  let ctx = @tpl.Context::new().set("name", @tpl.Value::Str("hello"))
  let result = render_with("{{ name | upper }}", ctx)
  @prelude.assert_eq!(result, "HELLO")
}

test "filter lower" {
  let ctx = @tpl.Context::new().set("name", @tpl.Value::Str("HELLO"))
  let result = render_with("{{ name | lower }}", ctx)
  @prelude.assert_eq!(result, "hello")
}

test "filter capitalize" {
  let ctx = @tpl.Context::new().set("name", @tpl.Value::Str("hello"))
  let result = render_with("{{ name | capitalize }}", ctx)
  @prelude.assert_eq!(result, "Hello")
}

test "filter trim" {
  let ctx = @tpl.Context::new().set("name", @tpl.Value::Str("  hello  "))
  let result = render_with("{{ name | trim }}", ctx)
  @prelude.assert_eq!(result, "hello")
}

test "filter length on string" {
  let ctx = @tpl.Context::new().set("name", @tpl.Value::Str("hello"))
  let result = render_with("{{ name | length }}", ctx)
  @prelude.assert_eq!(result, "5")
}

test "filter length on array" {
  let arr = @tpl.Value::Array([
    @tpl.Value::Int(1L),
    @tpl.Value::Int(2L),
    @tpl.Value::Int(3L),
  ])
  let ctx = @tpl.Context::new().set("items", arr)
  let result = render_with("{{ items | length }}", ctx)
  @prelude.assert_eq!(result, "3")
}

test "filter reverse string" {
  let ctx = @tpl.Context::new().set("name", @tpl.Value::Str("abc"))
  let result = render_with("{{ name | reverse }}", ctx)
  @prelude.assert_eq!(result, "cba")
}

test "filter reverse array" {
  let arr = @tpl.Value::Array([
    @tpl.Value::Int(1L),
    @tpl.Value::Int(2L),
    @tpl.Value::Int(3L),
  ])
  let ctx = @tpl.Context::new().set("nums", arr)
  let result = render_with("{{ nums | reverse | join(',') }}", ctx)
  @prelude.assert_eq!(result, "3,2,1")
}

test "filter first string" {
  let ctx = @tpl.Context::new().set("name", @tpl.Value::Str("hello"))
  let result = render_with("{{ name | first }}", ctx)
  @prelude.assert_eq!(result, "h")
}

test "filter first array" {
  let arr = @tpl.Value::Array([
    @tpl.Value::Str("a"),
    @tpl.Value::Str("b"),
    @tpl.Value::Str("c"),
  ])
  let ctx = @tpl.Context::new().set("items", arr)
  let result = render_with("{{ items | first }}", ctx)
  @prelude.assert_eq!(result, "a")
}

test "filter last string" {
  let ctx = @tpl.Context::new().set("name", @tpl.Value::Str("hello"))
  let result = render_with("{{ name | last }}", ctx)
  @prelude.assert_eq!(result, "o")
}

test "filter last array" {
  let arr = @tpl.Value::Array([
    @tpl.Value::Str("a"),
    @tpl.Value::Str("b"),
    @tpl.Value::Str("c"),
  ])
  let ctx = @tpl.Context::new().set("items", arr)
  let result = render_with("{{ items | last }}", ctx)
  @prelude.assert_eq!(result, "c")
}

// =============================================================================
// 2. Filters with arguments
// =============================================================================

test "filter join with separator" {
  let arr = @tpl.Value::Array([
    @tpl.Value::Str("a"),
    @tpl.Value::Str("b"),
    @tpl.Value::Str("c"),
  ])
  let ctx = @tpl.Context::new().set("items", arr)
  let result = render_with("{{ items | join(', ') }}", ctx)
  @prelude.assert_eq!(result, "a, b, c")
}

test "filter join with no separator" {
  let arr = @tpl.Value::Array([
    @tpl.Value::Str("a"),
    @tpl.Value::Str("b"),
  ])
  let ctx = @tpl.Context::new().set("items", arr)
  let result = render_with("{{ items | join }}", ctx)
  @prelude.assert_eq!(result, "ab")
}

test "filter replace" {
  let ctx = @tpl.Context::new().set("text", @tpl.Value::Str("hello world"))
  let result = render_with("{{ text | replace('world', 'MoonBit') }}", ctx)
  @prelude.assert_eq!(result, "hello MoonBit")
}

test "filter default with value" {
  let ctx = @tpl.Context::new().set("name", @tpl.Value::Str("Alice"))
  let result = render_with("{{ name | default('Guest') }}", ctx)
  @prelude.assert_eq!(result, "Alice")
}

test "filter default with empty" {
  let ctx = @tpl.Context::new().set("name", @tpl.Value::Str(""))
  let result = render_with("{{ name | default('Guest') }}", ctx)
  @prelude.assert_eq!(result, "Guest")
}

test "filter default with null" {
  let ctx = @tpl.Context::new()
  let result = render_with("{{ missing | default('N/A') }}", ctx)
  @prelude.assert_eq!(result, "N/A")
}

test "filter int from string" {
  let ctx = @tpl.Context::new().set("num", @tpl.Value::Str("42"))
  let result = render_with("{{ num | int }}", ctx)
  @prelude.assert_eq!(result, "42")
}

test "filter int from float" {
  let ctx = @tpl.Context::new().set("num", @tpl.Value::Float(3.9))
  let result = render_with("{{ num | int }}", ctx)
  @prelude.assert_eq!(result, "3")
}

test "filter string" {
  let ctx = @tpl.Context::new().set("num", @tpl.Value::Int(42L))
  let result = render_with("{{ num | string }}", ctx)
  @prelude.assert_eq!(result, "42")
}

// =============================================================================
// 3. Chained filters
// =============================================================================

test "filter chain upper + trim" {
  let ctx = @tpl.Context::new().set("name", @tpl.Value::Str("  hello  "))
  let result = render_with("{{ name | trim | upper }}", ctx)
  @prelude.assert_eq!(result, "HELLO")
}

test "filter chain lower + capitalize" {
  let ctx = @tpl.Context::new().set("name", @tpl.Value::Str("HELLO"))
  let result = render_with("{{ name | lower | capitalize }}", ctx)
  @prelude.assert_eq!(result, "Hello")
}

test "filter chain reverse + upper" {
  let ctx = @tpl.Context::new().set("name", @tpl.Value::Str("abc"))
  let result = render_with("{{ name | reverse | upper }}", ctx)
  @prelude.assert_eq!(result, "CBA")
}

// =============================================================================
// 4. Filters in if conditions
// =============================================================================

test "filter in if condition" {
  let ctx = @tpl.Context::new().set("name", @tpl.Value::Str("hello"))
  let result = render_with(
    "{% if (name | upper) == 'HELLO' %}yes{% else %}no{% endif %}",
    ctx,
  )
  @prelude.assert_eq!(result, "yes")
}

test "filter length in comparison" {
  let arr = @tpl.Value::Array([
    @tpl.Value::Int(1L),
    @tpl.Value::Int(2L),
    @tpl.Value::Int(3L),
  ])
  let ctx = @tpl.Context::new().set("items", arr)
  let result = render_with(
    "{% if (items | length) > 2 %}many{% else %}few{% endif %}",
    ctx,
  )
  @prelude.assert_eq!(result, "many")
}

// =============================================================================
// 5. Filter in for loop
// =============================================================================

test "filter in for loop body" {
  let arr = @tpl.Value::Array([
    @tpl.Value::Str("a"),
    @tpl.Value::Str("b"),
    @tpl.Value::Str("c"),
  ])
  let ctx = @tpl.Context::new().set("items", arr)
  let result = render_with(
    "{% for x in items %}{{ x | upper }}{% endfor %}",
    ctx,
  )
  @prelude.assert_eq!(result, "ABC")
}
