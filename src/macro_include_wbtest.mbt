// ---------------------------------------------------------------------------
// MoonTera — Macro and Include tests
// ---------------------------------------------------------------------------

// ===========================================================================
// Macro tests
// ===========================================================================

test "macro — simple call" {
  let loader = TemplateLoader::new()
  let loader = match loader.add_template("test.html",
    "{% macro hello() %}Hello World{% endmacro %}{{ hello() }}"
  ) {
    Ok(l) => l
    Err(_) => { assert_true!(false); loader }
  }
  match loader.render("test.html", Context::new()) {
    Ok(output) => assert_true!(output == "Hello World")
    Err(_) => assert_true!(false)
  }
}

test "macro — with one parameter" {
  let loader = TemplateLoader::new()
  let loader = match loader.add_template("test.html",
    "{% macro greet(name) %}Hello {{ name }}{% endmacro %}{{ greet(\"MoonBit\") }}"
  ) {
    Ok(l) => l
    Err(_) => { assert_true!(false); loader }
  }
  match loader.render("test.html", Context::new()) {
    Ok(output) => assert_true!(output == "Hello MoonBit")
    Err(_) => assert_true!(false)
  }
}

test "macro — with context variables" {
  let loader = TemplateLoader::new()
  let loader = match loader.add_template("test.html",
    "{% macro show() %}{{ title }}{% endmacro %}{{ show() }}"
  ) {
    Ok(l) => l
    Err(_) => { assert_true!(false); loader }
  }
  let ctx = Context::new()
  ctx.set("title", Value::Str("Home"))
  match loader.render("test.html", ctx) {
    Ok(output) => assert_true!(output == "Home")
    Err(_) => assert_true!(false)
  }
}

test "macro — with for loop inside" {
  let loader = TemplateLoader::new()
  let loader = match loader.add_template("test.html",
    "{% macro list(items) %}{% for x in items %}{{ x }},{% endfor %}{% endmacro %}{{ list(arr) }}"
  ) {
    Ok(l) => l
    Err(_) => { assert_true!(false); loader }
  }
  let ctx = Context::new()
  let arr = [Value::Int(1L), Value::Int(2L), Value::Int(3L)]
  ctx.set("arr", Value::Array(arr))
  match loader.render("test.html", ctx) {
    Ok(output) => assert_true!(output == "1,2,3,")
    Err(_) => assert_true!(false)
  }
}

// ===========================================================================
// Include tests
// ===========================================================================

test "include — simple include" {
  let loader = TemplateLoader::new()
  let loader = match loader.add_template("header.html", "HEADER") {
    Ok(l) => l
    Err(_) => { assert_true!(false); loader }
  }
  let loader = match loader.add_template("page.html",
    "{% include \"header.html\" %}BODY"
  ) {
    Ok(l) => l
    Err(_) => { assert_true!(false); loader }
  }
  match loader.render("page.html", Context::new()) {
    Ok(output) => assert_true!(output == "HEADERBODY")
    Err(_) => assert_true!(false)
  }
}

test "include — with context variables" {
  let loader = TemplateLoader::new()
  let loader = match loader.add_template("partial.html", "[{{ name }}]") {
    Ok(l) => l
    Err(_) => { assert_true!(false); loader }
  }
  let loader = match loader.add_template("page.html",
    "{% include \"partial.html\" %}"
  ) {
    Ok(l) => l
    Err(_) => { assert_true!(false); loader }
  }
  let ctx = Context::new()
  ctx.set("name", Value::Str("World"))
  match loader.render("page.html", ctx) {
    Ok(output) => assert_true!(output == "[World]")
    Err(_) => assert_true!(false)
  }
}

test "include — missing template error" {
  let loader = TemplateLoader::new()
  let loader = match loader.add_template("page.html", "{% include \"missing.html\" %}") {
    Ok(l) => l
    Err(_) => { assert_true!(false); loader }
  }
  match loader.render("page.html", Context::new()) {
    Ok(_) => assert_true!(false)
    Err(_) => assert_true!(true)
  }
}
