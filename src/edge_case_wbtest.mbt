// ---------------------------------------------------------------------------
// MoonTera — Edge case and complex integration tests
// ---------------------------------------------------------------------------

// ===========================================================================
// Filter edge cases
// ===========================================================================

test "filter — upper on empty string" {
  let ctx = Context::new()
  ctx.set("x", Value::Str(""))
  match Template::parse("test", "{{ x | upper }}") {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => assert_true!(output == "")
      Err(_) => assert_true!(false)
    }
    Err(_) => assert_true!(false)
  }
}

test "filter — length on empty string" {
  let ctx = Context::new()
  ctx.set("x", Value::Str(""))
  match Template::parse("test", "{{ x | length }}") {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => assert_true!(output == "0")
      Err(_) => assert_true!(false)
    }
    Err(_) => assert_true!(false)
  }
}

test "filter — length on empty array" {
  let ctx = Context::new()
  ctx.set("x", Value::Array([]))
  match Template::parse("test", "{{ x | length }}") {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => assert_true!(output == "0")
      Err(_) => assert_true!(false)
    }
    Err(_) => assert_true!(false)
  }
}

test "filter — join with empty array" {
  let ctx = Context::new()
  ctx.set("x", Value::Array([]))
  match Template::parse("test", "{{ x | join:\",\" }}") {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => assert_true!(output == "")
      Err(_) => assert_true!(false)
    }
    Err(_) => assert_true!(false)
  }
}

test "filter — join with single element" {
  let ctx = Context::new()
  ctx.set("x", Value::Array([Value::Str("only")]))
  match Template::parse("test", "{{ x | join:\",\" }}") {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => assert_true!(output == "only")
      Err(_) => assert_true!(false)
    }
    Err(_) => assert_true!(false)
  }
}

test "filter — replace no match" {
  let ctx = Context::new()
  ctx.set("x", Value::Str("hello"))
  match Template::parse("test", "{{ x | replace:\"x\":\"y\" }}") {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => assert_true!(output == "hello")
      Err(_) => assert_true!(false)
    }
    Err(_) => assert_true!(false)
  }
}

test "filter — replace all occurrences" {
  let ctx = Context::new()
  ctx.set("x", Value::Str("ababa"))
  match Template::parse("test", "{{ x | replace:\"a\":\"x\" }}") {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => assert_true!(output == "xbxbx")
      Err(_) => assert_true!(false)
    }
    Err(_) => assert_true!(false)
  }
}

test "filter — capitalize empty" {
  let ctx = Context::new()
  ctx.set("x", Value::Str(""))
  match Template::parse("test", "{{ x | capitalize }}") {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => assert_true!(output == "")
      Err(_) => assert_true!(false)
    }
    Err(_) => assert_true!(false)
  }
}

test "filter — reverse empty" {
  let ctx = Context::new()
  ctx.set("x", Value::Str(""))
  match Template::parse("test", "{{ x | reverse }}") {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => assert_true!(output == "")
      Err(_) => assert_true!(false)
    }
    Err(_) => assert_true!(false)
  }
}

test "filter — first on empty string" {
  let ctx = Context::new()
  ctx.set("x", Value::Str(""))
  match Template::parse("test", "{{ x | first }}") {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => assert_true!(output == "")
      Err(_) => assert_true!(false)
    }
    Err(_) => assert_true!(false)
  }
}

test "filter — last on empty string" {
  let ctx = Context::new()
  ctx.set("x", Value::Str(""))
  match Template::parse("test", "{{ x | last }}") {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => assert_true!(output == "")
      Err(_) => assert_true!(false)
    }
    Err(_) => assert_true!(false)
  }
}

test "filter — int from float" {
  let ctx = Context::new()
  ctx.set("x", Value::Float(3.9))
  match Template::parse("test", "{{ x | int }}") {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => assert_true!(output == "3")
      Err(_) => assert_true!(false)
    }
    Err(_) => assert_true!(false)
  }
}

test "filter — string from int" {
  let ctx = Context::new()
  ctx.set("x", Value::Int(42L))
  match Template::parse("test", "{{ x | string }}") {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => assert_true!(output == "42")
      Err(_) => assert_true!(false)
    }
    Err(_) => assert_true!(false)
  }
}

test "filter — chain: trim + upper" {
  let ctx = Context::new()
  ctx.set("x", Value::Str("  hello  "))
  match Template::parse("test", "{{ x | trim | upper }}") {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => assert_true!(output == "HELLO")
      Err(_) => assert_true!(false)
    }
    Err(_) => assert_true!(false)
  }
}

test "filter — chain: upper + length" {
  let ctx = Context::new()
  ctx.set("x", Value::Str("abc"))
  match Template::parse("test", "{{ x | upper | length }}") {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => assert_true!(output == "3")
      Err(_) => assert_true!(false)
    }
    Err(_) => assert_true!(false)
  }
}

// ===========================================================================
// Complex template combinations
// ===========================================================================

test "complex — mixed text, vars, if, for" {
  let ctx = Context::new()
  let items = [Value::Str("a"), Value::Str("b")]
  ctx.set("items", Value::Array(items))
  ctx.set("show", Value::Bool(true))
  match Template::parse("test",
    "{% if show %}List: {% for x in items %}[{{ loop.index }}:{{ x }}]{% endfor %}{% endif %}"
  ) {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => assert_true!(output == "List: [1:a][2:b]")
      Err(_) => assert_true!(false)
    }
    Err(_) => assert_true!(false)
  }
}

test "complex — for with if filter inside" {
  let ctx = Context::new()
  let nums = [Value::Int(1L), Value::Int(2L), Value::Int(3L), Value::Int(4L)]
  ctx.set("nums", Value::Array(nums))
  match Template::parse("test",
    "{% for n in nums %}{% if loop.first %}[{% endif %}{{ n }}{% if loop.last %}]{% else %},{% endif %}{% endfor %}"
  ) {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => assert_true!(output == "[1,2,3,4]")
      Err(_) => assert_true!(false)
    }
    Err(_) => assert_true!(false)
  }
}

test "complex — nested for loops" {
  let ctx = Context::new()
  let outer = [Value::Str("A"), Value::Str("B")]
  let inner = [Value::Int(1L), Value::Int(2L)]
  ctx.set("outer", Value::Array(outer))
  ctx.set("inner", Value::Array(inner))
  match Template::parse("test",
    "{% for o in outer %}{{ o }}:{% for i in inner %}{{ i }}{% endfor %};{% endfor %}"
  ) {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => assert_true!(output == "A:12;B:12;")
      Err(_) => assert_true!(false)
    }
    Err(_) => assert_true!(false)
  }
}

test "complex — filter inside for loop" {
  let ctx = Context::new()
  let items = [Value::Str("a"), Value::Str("b")]
  ctx.set("items", Value::Array(items))
  match Template::parse("test", "{% for x in items %}{{ x | upper }}{% endfor %}") {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => assert_true!(output == "AB")
      Err(_) => assert_true!(false)
    }
    Err(_) => assert_true!(false)
  }
}

test "complex — macro with for inside" {
  let loader = TemplateLoader::new()
  let loader = match loader.add_template("test.html",
    "{% macro list(items) %}{% for x in items %}<li>{{ x }}</li>{% endfor %}{% endmacro %}<ul>{{ list(arr) }}</ul>"
  ) {
    Ok(l) => l
    Err(_) => { assert_true!(false); loader }
  }
  let ctx = Context::new()
  let arr = [Value::Str("a"), Value::Str("b")]
  ctx.set("arr", Value::Array(arr))
  match loader.render("test.html", ctx) {
    Ok(output) => assert_true!(output == "<ul><li>a</li><li>b</li></ul>")
    Err(_) => assert_true!(false)
  }
}

test "complex — inheritance with for and if in block" {
  let loader = TemplateLoader::new()
  let loader = match loader.add_template("base.html",
    "<ul>{% block list %}*{% endblock %}</ul>"
  ) {
    Ok(l) => l
    Err(_) => { assert_true!(false); loader }
  }
  let loader = match loader.add_template("page.html",
    "{% extends \"base.html\" %}{% block list %}{% for item in items %}{% if item.show %}<li>{{ item.name }}</li>{% endif %}{% endfor %}{% endblock %}"
  ) {
    Ok(l) => l
    Err(_) => { assert_true!(false); loader }
  }
  // Build items with show flags
  let ctx = Context::new()
  let item1 = Map::new()
  item1["name"] = Value::Str("A")
  item1["show"] = Value::Bool(true)
  let item2 = Map::new()
  item2["name"] = Value::Str("B")
  item2["show"] = Value::Bool(false)
  let item3 = Map::new()
  item3["name"] = Value::Str("C")
  item3["show"] = Value::Bool(true)
  ctx.set("items", Value::Array([Value::Object(item1), Value::Object(item2), Value::Object(item3)]))
  match loader.render("page.html", ctx) {
    Ok(output) => assert_true!(output == "<ul><li>A</li><li>C</li></ul>")
    Err(_) => assert_true!(false)
  }
}

// ===========================================================================
// Inheritance edge cases
// ===========================================================================

test "inheritance — grandchild overrides parent" {
  let loader = TemplateLoader::new()
  let loader = match loader.add_template("grandpa.html",
    "{% block a %}A{% endblock %}{% block b %}B{% endblock %}{% block c %}C{% endblock %}"
  ) { Ok(l) => l; Err(_) => { assert_true!(false); loader } }
  let loader = match loader.add_template("parent.html",
    "{% extends \"grandpa.html\" %}{% block b %}B2{% endblock %}"
  ) { Ok(l) => l; Err(_) => { assert_true!(false); loader } }
  let loader = match loader.add_template("child.html",
    "{% extends \"parent.html\" %}{% block c %}C3{% endblock %}"
  ) { Ok(l) => l; Err(_) => { assert_true!(false); loader } }
  match loader.render("child.html", Context::new()) {
    Ok(output) => assert_true!(output == "AB2C3")
    Err(_) => assert_true!(false)
  }
}

test "inheritance — child only defines some blocks" {
  let loader = TemplateLoader::new()
  let loader = match loader.add_template("base.html",
    "X{% block a %}A{% endblock %}Y{% block b %}B{% endblock %}Z"
  ) { Ok(l) => l; Err(_) => { assert_true!(false); loader } }
  let loader = match loader.add_template("child.html",
    "{% extends \"base.html\" %}{% block a %}A2{% endblock %}"
  ) { Ok(l) => l; Err(_) => { assert_true!(false); loader } }
  match loader.render("child.html", Context::new()) {
    Ok(output) => assert_true!(output == "XA2YBZ")
    Err(_) => assert_true!(false)
  }
}

// ===========================================================================
// Error scenarios
// ===========================================================================

test "error — for loop on non-array" {
  let ctx = Context::new()
  ctx.set("x", Value::Str("not_array"))
  match Template::parse("test", "{% for i in x %}{{ i }}{% endfor %}") {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(_) => assert_true!(false)
      Err(_) => assert_true!(true)
    }
    Err(_) => assert_true!(false)
  }
}

test "error — undefined variable in expression" {
  let ctx = Context::new()
  match Template::parse("test", "{{ a + b }}") {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(_) => assert_true!(false)
      Err(_) => assert_true!(true)
    }
    Err(_) => assert_true!(false)
  }
}

test "error — filter on wrong type" {
  let ctx = Context::new()
  ctx.set("x", Value::Int(42L))
  match Template::parse("test", "{{ x | upper }}") {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(_) => assert_true!(false)
      Err(_) => assert_true!(true)
    }
    Err(_) => assert_true!(false)
  }
}

test "error — invalid filter name" {
  let ctx = Context::new()
  ctx.set("x", Value::Str("hello"))
  match Template::parse("test", "{{ x | nonexistent }}") {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(_) => assert_true!(false)
      Err(_) => assert_true!(true)
    }
    Err(_) => assert_true!(false)
  }
}
