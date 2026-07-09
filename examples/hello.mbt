// Hello World — minimal MoonTera example.
//
// Run with: moon run examples/hello.mbt

fn main {
  // 1. Parse a template from a string.
  let tpl_result = @template.Template::parse("Hello, {{ name }}!")
  let tpl = match tpl_result {
    Ok(t) => t
    Err(err) => {
      println("Parse error: " + err.to_string())
      return
    }
  }

  // 2. Build a rendering context with variables.
  let ctx = @template.Context::new()
    .set("name", @template.Value::Str("MoonBit"))

  // 3. Render the template against the context.
  let result = tpl.render(ctx)
  match result {
    Ok(output) => println(output)  // "Hello, MoonBit!"
    Err(err) => println("Render error: " + err.to_string())
  }
}
