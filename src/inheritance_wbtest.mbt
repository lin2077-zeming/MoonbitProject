// ---------------------------------------------------------------------------
// MoonTera — Template inheritance tests
// ---------------------------------------------------------------------------

test "inheritance — simple block override" {
  let loader = TemplateLoader::new()
  let loader = match loader.add_template("base.html", "<html><head>{% block title %}Default{% endblock %}</head></html>") {
    Ok(l) => l
    Err(_) => { assert_true!(false); loader }
  }
  let loader = match loader.add_template("page.html", "{% extends \"base.html\" %}{% block title %}My Page{% endblock %}") {
    Ok(l) => l
    Err(_) => { assert_true!(false); loader }
  }
  let ctx = Context::new()
  match loader.render("page.html", ctx) {
    Ok(output) => assert_true!(output == "<html><head>My Page</head></html>")
    Err(_) => assert_true!(false)
  }
}

test "inheritance — child content outside blocks ignored" {
  let loader = TemplateLoader::new()
  let loader = match loader.add_template("base.html", "A{% block x %}B{% endblock %}C") {
    Ok(l) => l
    Err(_) => { assert_true!(false); loader }
  }
  let loader = match loader.add_template("page.html", "{% extends \"base.html\" %}{% block x %}X{% endblock %}extra") {
    Ok(l) => l
    Err(_) => { assert_true!(false); loader }
  }
  let ctx = Context::new()
  match loader.render("page.html", ctx) {
    Ok(output) => assert_true!(output == "AXC")
    Err(_) => assert_true!(false)
  }
}

test "inheritance — multiple blocks" {
  let loader = TemplateLoader::new()
  let loader = match loader.add_template("base.html",
    "<head>{% block title %}T{% endblock %}</head><body>{% block body %}B{% endblock %}</body>"
  ) {
    Ok(l) => l
    Err(_) => { assert_true!(false); loader }
  }
  let loader = match loader.add_template("page.html",
    "{% extends \"base.html\" %}{% block title %}Hello{% endblock %}{% block body %}World{% endblock %}"
  ) {
    Ok(l) => l
    Err(_) => { assert_true!(false); loader }
  }
  let ctx = Context::new()
  match loader.render("page.html", ctx) {
    Ok(output) => assert_true!(output == "<head>Hello</head><body>World</body>")
    Err(_) => assert_true!(false)
  }
}

test "inheritance — un-overridden block uses default" {
  let loader = TemplateLoader::new()
  let loader = match loader.add_template("base.html",
    "{% block a %}A{% endblock %}{% block b %}B{% endblock %}"
  ) {
    Ok(l) => l
    Err(_) => { assert_true!(false); loader }
  }
  let loader = match loader.add_template("page.html",
    "{% extends \"base.html\" %}{% block b %}B2{% endblock %}"
  ) {
    Ok(l) => l
    Err(_) => { assert_true!(false); loader }
  }
  let ctx = Context::new()
  match loader.render("page.html", ctx) {
    Ok(output) => assert_true!(output == "AB2")
    Err(_) => assert_true!(false)
  }
}

test "inheritance — block with variables" {
  let loader = TemplateLoader::new()
  let loader = match loader.add_template("base.html",
    "<title>{% block title %}Default{% endblock %}</title>"
  ) {
    Ok(l) => l
    Err(_) => { assert_true!(false); loader }
  }
  let loader = match loader.add_template("page.html",
    "{% extends \"base.html\" %}{% block title %}{{ name }}{% endblock %}"
  ) {
    Ok(l) => l
    Err(_) => { assert_true!(false); loader }
  }
  let ctx = Context::new()
  ctx.set("name", Value::Str("MoonBit"))
  match loader.render("page.html", ctx) {
    Ok(output) => assert_true!(output == "<title>MoonBit</title>")
    Err(_) => assert_true!(false)
  }
}

test "inheritance — block with for loop" {
  let loader = TemplateLoader::new()
  let loader = match loader.add_template("base.html",
    "<ul>{% block list %}*{% endblock %}</ul>"
  ) {
    Ok(l) => l
    Err(_) => { assert_true!(false); loader }
  }
  let loader = match loader.add_template("page.html",
    "{% extends \"base.html\" %}{% block list %}{% for item in items %}<li>{{ item }}</li>{% endfor %}{% endblock %}"
  ) {
    Ok(l) => l
    Err(_) => { assert_true!(false); loader }
  }
  let ctx = Context::new()
  let items = [Value::Str("a"), Value::Str("b")]
  ctx.set("items", Value::Array(items))
  match loader.render("page.html", ctx) {
    Ok(output) => assert_true!(output == "<ul><li>a</li><li>b</li></ul>")
    Err(_) => assert_true!(false)
  }
}

test "inheritance — no extends renders directly" {
  let loader = TemplateLoader::new()
  let loader = match loader.add_template("plain.html", "Hello {{ name }}!") {
    Ok(l) => l
    Err(_) => { assert_true!(false); loader }
  }
  let ctx = Context::new()
  ctx.set("name", Value::Str("World"))
  match loader.render("plain.html", ctx) {
    Ok(output) => assert_true!(output == "Hello World!")
    Err(_) => assert_true!(false)
  }
}

test "inheritance — template not found" {
  let loader = TemplateLoader::new()
  let ctx = Context::new()
  match loader.render("missing.html", ctx) {
    Ok(_) => assert_true!(false)
    Err(_) => assert_true!(true)
  }
}
