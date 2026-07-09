// Copyright (c) 2024 LinZeming
// Released under the MIT License
//
// Black-box tests for macro definitions and calls.

fn render(source : String) -> String {
  let tpl_result = @tpl.Template::parse(source)
  let tpl = match tpl_result {
    Ok(t) => t
    Err(msg) => @prelude.fail("parse failed: " + msg)
  }
  let ctx = @tpl.Context::new()
  match tpl.render(ctx) {
    Ok(s) => s
    Err(msg) => @prelude.fail("render failed: " + msg)
  }
}

// =============================================================================
// 1. Simple macro definition and call
// =============================================================================

test "macro simple call" {
  let result = render(
    "{% macro hello() %}Hello, World!{% endmacro %}" +
    "{{ hello() }}",
  )
  @prelude.assert_eq!(result, "Hello, World!")
}

test "macro with one parameter" {
  let result = render(
    "{% macro greet(name) %}Hello, {{ name }}!{% endmacro %}" +
    "{{ greet('MoonBit') }}",
  )
  @prelude.assert_eq!(result, "Hello, MoonBit!")
}

test "macro with multiple parameters" {
  let result = render(
    "{% macro button(text, class) %}<button class=\"{{ class }}\">{{ text }}</button>{% endmacro %}" +
    "{{ button('Submit', 'primary') }}",
  )
  @prelude.assert_eq!(result, "<button class=\"primary\">Submit</button>")
}

// =============================================================================
// 2. Macro with repeated calls
// =============================================================================

test "macro called multiple times" {
  let result = render(
    "{% macro item(label) %}<li>{{ label }}</li>{% endmacro %}" +
    "{{ item('A') }}{{ item('B') }}{{ item('C') }}",
  )
  @prelude.assert_eq!(result, "<li>A</li><li>B</li><li>C</li>")
}

// =============================================================================
// 3. Macro in for loop
// =============================================================================

test "macro called inside for loop" {
  let result = render(
    "{% macro opt(val) %}<option>{{ val }}</option>{% endmacro %}" +
    "{% for x in items %}{{ opt(x) }}{% endfor %}",
  )
  // Without 'items' defined in context, this should fail or produce empty output.
  // Test with a context that has items.
  let ctx = @tpl.Context::new().set(
    "items",
    @tpl.Value::Array([
      @tpl.Value::Str("a"),
      @tpl.Value::Str("b"),
    ]),
  )
  let tpl = match @tpl.Template::parse(
    "{% macro opt(val) %}<option>{{ val }}</option>{% endmacro %}" +
    "{% for x in items %}{{ opt(x) }}{% endfor %}",
  ) {
    Ok(t) => t
    Err(msg) => @prelude.fail("parse: " + msg)
  }
  match tpl.render(ctx) {
    Ok(s) => @prelude.assert_eq!(s, "<option>a</option><option>b</option>")
    Err(msg) => @prelude.fail(msg)
  }
}

// =============================================================================
// 4. Macro using if/filters
// =============================================================================

test "macro with if inside" {
  let result = render(
    "{% macro badge(count) %}{% if count > 0 %}[{{ count }}]{% endif %}{% endmacro %}" +
    "{{ badge(5) }}{{ badge(0) }}",
  )
  @prelude.assert_eq!(result, "[5]")
}

test "macro with filter" {
  let result = render(
    "{% macro shout(msg) %}{{ msg | upper }}{% endmacro %}" +
    "{{ shout('hello') }}",
  )
  @prelude.assert_eq!(result, "HELLO")
}
