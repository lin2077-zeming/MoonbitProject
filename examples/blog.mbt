// Blog page example — loops, conditionals, and filters.

fn main {
  let source = #|<html>
<head><title>{{ title }}</title></head>
<body>
  <h1>{{ title }}</h1>

  {% if posts | length > 0 %}
    {% for post in posts %}
      <article>
        <h2>{{ loop.index }}. {{ post.title | upper }}</h2>
        <p>By {{ post.author | default("Anonymous") }}</p>
        <p>{{ post.summary | trim }}</p>
        {% if post.featured %}
          <span class="badge">★ Featured</span>
        {% endif %}
      </article>
    {% endfor %}
  {% else %}
    <p>No posts yet. Check back soon!</p>
  {% endif %}

  <footer>Total: {{ posts | length }} post(s)</footer>
</body>
</html>|#

  let tpl = match @template.Template::parse(source) {
    Ok(t) => t
    Err(err) => { println(err.to_string()); return }
  }

  // Build sample blog data.
  let posts = @template.Value::Array([
    @template.Value::Object(build_post(
      "MoonBit 0.1 Released",
      "LinZeming",
      "Introducing the new template engine...",
      true,
    )),
    @template.Value::Object(build_post(
      "Getting Started with MoonTera",
      "",
      "A quick guide to template rendering...  ",
      false,
    )),
    @template.Value::Object(build_post(
      "Advanced Macro Patterns",
      "Jane",
      "Reusable UI components with macros...",
      true,
    )),
  ])

  let ctx = @template.Context::new()
    .set("title", @template.Value::Str("My Blog"))
    .set("posts", posts)

  match tpl.render(ctx) {
    Ok(html) => println(html)
    Err(err) => println("Render error: " + err.to_string())
  }
}

/// Helper: build a post object map.
fn build_post(
  title : String,
  author : String,
  summary : String,
  featured : Bool
) -> Map[String, @template.Value] {
  let m : Map[String, @template.Value] = Map::new()
  m["title"] = @template.Value::Str(title)
  m["author"] = @template.Value::Str(author)
  m["summary"] = @template.Value::Str(summary)
  m["featured"] = @template.Value::Bool(featured)
  m
}
