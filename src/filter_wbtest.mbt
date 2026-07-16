// ---------------------------------------------------------------------------
// MoonTera — Filter integration tests
// ---------------------------------------------------------------------------

test "filter — upper" {
  let ctx = Context::new()
  ctx.set("name", Value::Str("hello"))
  match Template::parse("test", "{{ name | upper }}") {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => assert_true!(output == "HELLO")
      Err(_) => assert_true!(false)
    }
    Err(_) => assert_true!(false)
  }
}

test "filter — lower" {
  let ctx = Context::new()
  ctx.set("name", Value::Str("HELLO"))
  match Template::parse("test", "{{ name | lower }}") {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => assert_true!(output == "hello")
      Err(_) => assert_true!(false)
    }
    Err(_) => assert_true!(false)
  }
}

test "filter — trim" {
  let ctx = Context::new()
  ctx.set("text", Value::Str("  hello  "))
  match Template::parse("test", "{{ text | trim }}") {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => assert_true!(output == "hello")
      Err(_) => assert_true!(false)
    }
    Err(_) => assert_true!(false)
  }
}

test "filter — length" {
  let ctx = Context::new()
  ctx.set("text", Value::Str("hello"))
  match Template::parse("test", "{{ text | length }}") {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => assert_true!(output == "5")
      Err(_) => assert_true!(false)
    }
    Err(_) => assert_true!(false)
  }
}

test "filter — default keeps value" {
  let ctx = Context::new()
  ctx.set("name", Value::Str("MoonBit"))
  match Template::parse("test", "{{ name | default:\"N/A\" }}") {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => assert_true!(output == "MoonBit")
      Err(_) => assert_true!(false)
    }
    Err(_) => assert_true!(false)
  }
}

test "filter — default with empty" {
  let ctx = Context::new()
  ctx.set("name", Value::Str(""))
  match Template::parse("test", "{{ name | default:\"N/A\" }}") {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => assert_true!(output == "N/A")
      Err(_) => assert_true!(false)
    }
    Err(_) => assert_true!(false)
  }
}

test "filter — default with null" {
  let ctx = Context::new()
  ctx.set("x", Value::Null)
  match Template::parse("test", "{{ x | default:\"fallback\" }}") {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => assert_true!(output == "fallback")
      Err(_) => assert_true!(false)
    }
    Err(_) => assert_true!(false)
  }
}

test "filter — capitalize" {
  let ctx = Context::new()
  ctx.set("word", Value::Str("hello"))
  match Template::parse("test", "{{ word | capitalize }}") {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => assert_true!(output == "Hello")
      Err(_) => assert_true!(false)
    }
    Err(_) => assert_true!(false)
  }
}

test "filter — reverse" {
  let ctx = Context::new()
  ctx.set("s", Value::Str("abc"))
  match Template::parse("test", "{{ s | reverse }}") {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => assert_true!(output == "cba")
      Err(_) => assert_true!(false)
    }
    Err(_) => assert_true!(false)
  }
}

test "filter — first and last" {
  let ctx = Context::new()
  ctx.set("s", Value::Str("hello"))
  match Template::parse("test", "{{ s | first }}-{{ s | last }}") {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => assert_true!(output == "h-o")
      Err(_) => assert_true!(false)
    }
    Err(_) => assert_true!(false)
  }
}

test "filter — filter in if condition" {
  let ctx = Context::new()
  ctx.set("name", Value::Str("  hello  "))
  match Template::parse("test", "{% if name | trim == \"hello\" %}ok{% endif %}") {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => assert_true!(output == "ok")
      Err(_) => assert_true!(false)
    }
    Err(_) => assert_true!(false)
  }
}
