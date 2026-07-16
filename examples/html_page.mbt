// MoonTera Example: Render an HTML page with template inheritance
// Usage: moon run cmd/html_page

fn main {
  // Create a template loader
  let loader = TemplateLoader::new()

  // Add a base layout template
  let loader = match loader.add_template("layout.html",
    "<!DOCTYPE html>\n" +
    "<html>\n" +
    "<head>\n" +
    "  <meta charset=\"utf-8\">\n" +
    "  <title>{% block title %}My Site{% endblock %}</title>\n" +
    "</head>\n" +
    "<body>\n" +
    "  <header>{% block header %}Welcome{% endblock %}</header>\n" +
    "  <main>{% block content %}{% endblock %}</main>\n" +
    "  <footer>{% block footer %}&copy; 2025{% endblock %}</footer>\n" +
    "</body>\n" +
    "</html>"
  ) {
    Ok(l) => l
    Err(e) => { println(e.to_string()); return }
  }

  // Add a page that extends the layout
  let loader = match loader.add_template("home.html",
    "{% extends \"layout.html\" %}\n" +
    "{% block title %}Home — MoonTera{% endblock %}\n" +
    "{% block header %}<h1>MoonTera</h1><p>A MoonBit template engine</p>{% endblock %}\n" +
    "{% block content %}\n" +
    "  <h2>Features</h2>\n" +
    "  <ul>\n" +
    "    {% for feature in features %}\n" +
    "    <li>{{ feature }}</li>\n" +
    "    {% endfor %}\n" +
    "  </ul>\n" +
    "{% endblock %}"
  ) {
    Ok(l) => l
    Err(e) => { println(e.to_string()); return }
  }

  // Set up context
  let ctx = Context::new()
  let features = [
    Value::Str("Variables & Filters"),
    Value::Str("Conditionals (if/elif/else)"),
    Value::Str("For Loops with loop.index"),
    Value::Str("Template Inheritance"),
    Value::Str("Macros"),
    Value::Str("Includes"),
  ]
  ctx.set("features", Value::Array(features))

  // Render
  match loader.render("home.html", ctx) {
    Ok(output) => println(output)
    Err(e) => println("Error: " + e.to_string())
  }
}
