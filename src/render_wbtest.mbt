// ---------------------------------------------------------------------------
// MoonTera — Rendering integration tests
// ---------------------------------------------------------------------------

// ===========================================================================
// 1. Plain text templates
// ===========================================================================

test "render — plain text" {
  match Template::parse("test", "Hello World!") {
    Ok(tpl) => match tpl.render(Context::new()) {
      Ok(output) => assert_true!(output == "Hello World!")
      Err(e) => assert_true!(false)
    }
    Err(e) => assert_true!(false)
  }
}

test "render — empty template" {
  match Template::parse("test", "") {
    Ok(tpl) => match tpl.render(Context::new()) {
      Ok(output) => assert_true!(output == "")
      Err(e) => assert_true!(false)
    }
    Err(e) => assert_true!(false)
  }
}

test "render — multiline text" {
  let source = "line1\nline2\nline3"
  match Template::parse("test", source) {
    Ok(tpl) => match tpl.render(Context::new()) {
      Ok(output) => assert_true!(output == source)
      Err(e) => assert_true!(false)
    }
    Err(e) => assert_true!(false)
  }
}

// ===========================================================================
// 2. Single variable rendering
// ===========================================================================

test "render — single variable" {
  let ctx = Context::new()
  ctx.set("name", Value::Str("MoonBit"))
  match Template::parse("test", "Hello {{ name }}!") {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => assert_true!(output == "Hello MoonBit!")
      Err(e) => assert_true!(false)
    }
    Err(e) => assert_true!(false)
  }
}

test "render — variable at start" {
  let ctx = Context::new()
  ctx.set("x", Value::Int(42L))
  match Template::parse("test", "{{ x }}") {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => assert_true!(output == "42")
      Err(e) => assert_true!(false)
    }
    Err(e) => assert_true!(false)
  }
}

test "render — variable with string value" {
  let ctx = Context::new()
  ctx.set("greeting", Value::Str("Hi"))
  match Template::parse("test", "{{ greeting }} there") {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => assert_true!(output == "Hi there")
      Err(e) => assert_true!(false)
    }
    Err(e) => assert_true!(false)
  }
}

// ===========================================================================
// 3. Multiple variables mixed with text
// ===========================================================================

test "render — multiple variables" {
  let ctx = Context::new()
  ctx.set("a", Value::Str("foo"))
  ctx.set("b", Value::Str("bar"))
  match Template::parse("test", "{{ a }} and {{ b }}") {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => assert_true!(output == "foo and bar")
      Err(e) => assert_true!(false)
    }
    Err(e) => assert_true!(false)
  }
}

test "render — arithmetic in expression" {
  let ctx = Context::new()
  ctx.set("a", Value::Int(3L))
  ctx.set("b", Value::Int(4L))
  match Template::parse("test", "{{ a + b }}") {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => assert_true!(output == "7")
      Err(e) => assert_true!(false)
    }
    Err(e) => assert_true!(false)
  }
}

test "render — mixed text and vars" {
  let ctx = Context::new()
  ctx.set("x", Value::Int(1L))
  ctx.set("y", Value::Int(2L))
  match Template::parse("test", "{{ x }} + {{ y }} = {{ x + y }}") {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => assert_true!(output == "1 + 2 = 3")
      Err(e) => assert_true!(false)
    }
    Err(e) => assert_true!(false)
  }
}

// ===========================================================================
// 4. Variable type display
// ===========================================================================

test "render — int to string" {
  let ctx = Context::new()
  ctx.set("n", Value::Int(42L))
  match Template::parse("test", "{{ n }}") {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => assert_true!(output == "42")
      Err(e) => assert_true!(false)
    }
    Err(e) => assert_true!(false)
  }
}

test "render — float to string" {
  let ctx = Context::new()
  ctx.set("pi", Value::Float(3.14))
  match Template::parse("test", "{{ pi }}") {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => assert_true!(output == "3.14")
      Err(e) => assert_true!(false)
    }
    Err(e) => assert_true!(false)
  }
}

test "render — bool to string" {
  let ctx = Context::new()
  ctx.set("flag", Value::Bool(true))
  match Template::parse("test", "{{ flag }}") {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => assert_true!(output == "true")
      Err(e) => assert_true!(false)
    }
    Err(e) => assert_true!(false)
  }
}

test "render — null to string" {
  let ctx = Context::new()
  ctx.set("nothing", Value::Null)
  match Template::parse("test", "{{ nothing }}") {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => assert_true!(output == "null")
      Err(e) => assert_true!(false)
    }
    Err(e) => assert_true!(false)
  }
}

// ===========================================================================
// 5. Error handling
// ===========================================================================

test "render — undefined variable raises error" {
  match Template::parse("test", "{{ missing }}") {
    Ok(tpl) => match tpl.render(Context::new()) {
      Ok(_) => assert_true!(false)
      Err(_) => assert_true!(true)
    }
    Err(e) => assert_true!(false)
  }
}

test "render — parse error on unclosed variable" {
  match Template::parse("test", "Hello {{ name") {
    Ok(_) => assert_true!(false)
    Err(_) => assert_true!(true)
  }
}

// ===========================================================================
// 6. Conditional: if / elif / else / endif
// ===========================================================================

test "if — condition true renders then-body" {
  let ctx = Context::new()
  ctx.set("show", Value::Bool(true))
  match Template::parse("test", "{% if show %}Hello{% endif %}") {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => assert_true!(output == "Hello")
      Err(e) => assert_true!(false)
    }
    Err(e) => assert_true!(false)
  }
}

test "if — condition false renders nothing" {
  let ctx = Context::new()
  ctx.set("show", Value::Bool(false))
  match Template::parse("test", "{% if show %}Hello{% endif %}") {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => assert_true!(output == "")
      Err(e) => assert_true!(false)
    }
    Err(e) => assert_true!(false)
  }
}

test "if — int truthy/falsy" {
  let ctx = Context::new()
  ctx.set("x", Value::Int(5L))
  match Template::parse("test", "{% if x %}yes{% endif %}") {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => assert_true!(output == "yes")
      Err(e) => assert_true!(false)
    }
    Err(e) => assert_true!(false)
  }
}

test "if — int zero is falsy" {
  let ctx = Context::new()
  ctx.set("x", Value::Int(0L))
  match Template::parse("test", "{% if x %}yes{% endif %}") {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => assert_true!(output == "")
      Err(e) => assert_true!(false)
    }
    Err(e) => assert_true!(false)
  }
}

test "if — text around condition" {
  let ctx = Context::new()
  ctx.set("show", Value::Bool(true))
  match Template::parse("test", "before{% if show %}YES{% endif %}after") {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => assert_true!(output == "beforeYESafter")
      Err(e) => assert_true!(false)
    }
    Err(e) => assert_true!(false)
  }
}

test "if + else — true" {
  let ctx = Context::new()
  ctx.set("x", Value::Int(10L))
  match Template::parse("test", "{% if x > 5 %}big{% else %}small{% endif %}") {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => assert_true!(output == "big")
      Err(e) => assert_true!(false)
    }
    Err(e) => assert_true!(false)
  }
}

test "if + else — false" {
  let ctx = Context::new()
  ctx.set("x", Value::Int(3L))
  match Template::parse("test", "{% if x > 5 %}big{% else %}small{% endif %}") {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => assert_true!(output == "small")
      Err(e) => assert_true!(false)
    }
    Err(e) => assert_true!(false)
  }
}

test "if + elif + else — first elif matches" {
  let ctx = Context::new()
  ctx.set("score", Value::Int(85L))
  match Template::parse("test",
    "{% if score >= 90 %}A{% elif score >= 80 %}B{% elif score >= 70 %}C{% else %}F{% endif %}"
  ) {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => assert_true!(output == "B")
      Err(e) => assert_true!(false)
    }
    Err(e) => assert_true!(false)
  }
}

test "if + elif + else — second elif matches" {
  let ctx = Context::new()
  ctx.set("score", Value::Int(75L))
  match Template::parse("test",
    "{% if score >= 90 %}A{% elif score >= 80 %}B{% elif score >= 70 %}C{% else %}F{% endif %}"
  ) {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => assert_true!(output == "C")
      Err(e) => assert_true!(false)
    }
    Err(e) => assert_true!(false)
  }
}

test "if + elif + else — else fallback" {
  let ctx = Context::new()
  ctx.set("score", Value::Int(50L))
  match Template::parse("test",
    "{% if score >= 90 %}A{% elif score >= 80 %}B{% elif score >= 70 %}C{% else %}F{% endif %}"
  ) {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => assert_true!(output == "F")
      Err(e) => assert_true!(false)
    }
    Err(e) => assert_true!(false)
  }
}

test "if — comparison operators" {
  let ctx = Context::new()
  ctx.set("a", Value::Int(5L))
  ctx.set("b", Value::Int(5L))
  ctx.set("c", Value::Int(10L))
  match Template::parse("test",
    "{% if a == b %}eq{% endif %}{% if a != c %}neq{% endif %}{% if a < c %}lt{% endif %}"
  ) {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => assert_true!(output == "eqneqlt")
      Err(e) => assert_true!(false)
    }
    Err(e) => assert_true!(false)
  }
}

test "if — string comparison" {
  let ctx = Context::new()
  ctx.set("name", Value::Str("admin"))
  match Template::parse("test", "{% if name == \"admin\" %}welcome{% endif %}") {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => assert_true!(output == "welcome")
      Err(e) => assert_true!(false)
    }
    Err(e) => assert_true!(false)
  }
}

// ===========================================================================
// 7. For loop: {% for var in expr %} body {% endfor %}
// ===========================================================================

test "for — simple array iteration" {
  let ctx = Context::new()
  let items = [Value::Str("a"), Value::Str("b"), Value::Str("c")]
  ctx.set("items", Value::Array(items))
  match Template::parse("test", "{% for x in items %}{{ x }},{% endfor %}") {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => assert_true!(output == "a,b,c,")
      Err(e) => assert_true!(false)
    }
    Err(e) => assert_true!(false)
  }
}

test "for — with surrounding text" {
  let ctx = Context::new()
  let items = [Value::Int(1L), Value::Int(2L)]
  ctx.set("nums", Value::Array(items))
  match Template::parse("test", "[{% for n in nums %}{{ n }}{% endfor %}]") {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => assert_true!(output == "[12]")
      Err(e) => assert_true!(false)
    }
    Err(e) => assert_true!(false)
  }
}

test "for — empty array outputs nothing" {
  let ctx = Context::new()
  let items : Array[Value] = []
  ctx.set("items", Value::Array(items))
  match Template::parse("test", "{% for x in items %}X{% endfor %}") {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => assert_true!(output == "")
      Err(e) => assert_true!(false)
    }
    Err(e) => assert_true!(false)
  }
}

test "for — loop.index (1-based)" {
  let ctx = Context::new()
  let items = [Value::Str("a"), Value::Str("b")]
  ctx.set("items", Value::Array(items))
  match Template::parse("test", "{% for x in items %}{{ loop.index }}{% endfor %}") {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => assert_true!(output == "12")
      Err(e) => assert_true!(false)
    }
    Err(e) => assert_true!(false)
  }
}

test "for — loop.index0 (0-based)" {
  let ctx = Context::new()
  let items = [Value::Str("x"), Value::Str("y"), Value::Str("z")]
  ctx.set("items", Value::Array(items))
  match Template::parse("test", "{% for x in items %}{{ loop.index0 }}{% endfor %}") {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => assert_true!(output == "012")
      Err(e) => assert_true!(false)
    }
    Err(e) => assert_true!(false)
  }
}

test "for — loop.first and loop.last" {
  let ctx = Context::new()
  let items = [Value::Int(1L), Value::Int(2L), Value::Int(3L)]
  ctx.set("items", Value::Array(items))
  match Template::parse("test",
    "{% for x in items %}{% if loop.first %}[{% endif %}{{ x }}{% if loop.last %}]{% endif %}{% endfor %}"
  ) {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => assert_true!(output == "[123]")
      Err(e) => assert_true!(false)
    }
    Err(e) => assert_true!(false)
  }
}

test "for — not loop.last for separator" {
  let ctx = Context::new()
  let items = [Value::Str("a"), Value::Str("b"), Value::Str("c")]
  ctx.set("items", Value::Array(items))
  match Template::parse("test",
    "{% for x in items %}{{ x }}{% if not loop.last %},{% endif %}{% endfor %}"
  ) {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => assert_true!(output == "a,b,c")
      Err(e) => assert_true!(false)
    }
    Err(e) => assert_true!(false)
  }
}

test "for — loop.length" {
  let ctx = Context::new()
  let items = [Value::Int(1L), Value::Int(2L)]
  ctx.set("items", Value::Array(items))
  match Template::parse("test", "{% for x in items %}{{ loop.length }}{% endfor %}") {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => assert_true!(output == "22")
      Err(e) => assert_true!(false)
    }
    Err(e) => assert_true!(false)
  }
}

test "for — nested if inside loop" {
  let ctx = Context::new()
  let items = [Value::Int(1L), Value::Int(2L), Value::Int(3L), Value::Int(4L)]
  ctx.set("nums", Value::Array(items))
  match Template::parse("test",
    "{% for n in nums %}{% if n > 2 %}{{ n }}{% endif %}{% endfor %}"
  ) {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => assert_true!(output == "34")
      Err(e) => assert_true!(false)
    }
    Err(e) => assert_true!(false)
  }
}

test "for — arithmetic in loop" {
  let ctx = Context::new()
  let items = [Value::Int(10L), Value::Int(20L), Value::Int(30L)]
  ctx.set("vals", Value::Array(items))
  match Template::parse("test",
    "{% for v in vals %}{{ v + 1 }},{% endfor %}"
  ) {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => assert_true!(output == "11,21,31,")
      Err(e) => assert_true!(false)
    }
    Err(e) => assert_true!(false)
  }
}
