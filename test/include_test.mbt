// Copyright (c) 2024 LinZeming
// Released under the MIT License
//
// Black-box tests for `{% include %}`.

/// Helper: render with a loader pre-populated with templates.
fn render_with_includes(
  main_src : String,
  includes : Array[(String, String)],
  ctx : @tpl.Context
) -> String {
  let tpl_result = @tpl.Template::parse(main_src)
  let tpl = match tpl_result {
    Ok(t) => t
    Err(msg) => @prelude.fail("parse failed: " + msg)
  }
  let mut loader = @tpl.TemplateLoader::new()
  for (name, src) in includes {
    loader = loader.add(name, src)
  }
  match tpl.render_with_loader(ctx, loader) {
    Ok(s) => s
    Err(msg) => @prelude.fail("render failed: " + msg)
  }
}

// =============================================================================
// 1. Simple include
// =============================================================================

test "include simple partial" {
  let result = render_with_includes(
    "Before {% include 'part' %} After",
    [("part", "INCLUDED")],
    @tpl.Context::new(),
  )
  @prelude.assert_eq!(result, "Before INCLUDED After")
}

test "include with variable from parent context" {
  let ctx = @tpl.Context::new().set("name", @tpl.Value::Str("MoonBit"))
  let result = render_with_includes(
    "Hello, {% include 'greet' %}!",
    [("greet", "{{ name }}")],
    ctx,
  )
  @prelude.assert_eq!(result, "Hello, MoonBit!")
}

test "include multiple partials" {
  let ctx = @tpl.Context::new()
  let result = render_with_includes(
    "{% include 'a' %} + {% include 'b' %}",
    [("a", "1"), ("b", "2")],
    ctx,
  )
  @prelude.assert_eq!(result, "1 + 2")
}

// =============================================================================
// 2. Include with filters and macros in sub-template
// =============================================================================

test "include with filters in partial" {
  let ctx = @tpl.Context::new().set("name", @tpl.Value::Str("hello"))
  let result = render_with_includes(
    "{% include 'part' %}",
    [("part", "{{ name | upper }}")],
    ctx,
  )
  @prelude.assert_eq!(result, "HELLO")
}

test "include with macro in partial" {
  let ctx = @tpl.Context::new()
  let result = render_with_includes(
    "{% include 'macros' %}{{ btn('OK') }}",
    [("macros", "{% macro btn(label) %}[{{ label }}]{% endmacro %}")],
    ctx,
  )
  @prelude.assert_eq!(result, "[OK]")
}

test "include not found" {
  let tpl_result = @tpl.Template::parse("{% include 'missing' %}")
  let tpl = match tpl_result {
    Ok(t) => t
    Err(msg) => @prelude.fail("parse: " + msg)
  }
  let loader = @tpl.TemplateLoader::new()
  match tpl.render_with_loader(@tpl.Context::new(), loader) {
    Ok(_) => @prelude.assert_false!(true)
    Err(_) => @prelude.assert_true!(true)
  }
}
