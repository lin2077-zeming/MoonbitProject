// ---------------------------------------------------------------------------
// MoonTera — Public API
//
// Re-exports all public types and functions from the template engine.
//
// Usage:
//   let tpl = Template::parse("index.html", "Hello {{ name }}!")!
//   let ctx = Context::new()
//   ctx.set("name", Value::Str("MoonBit"))
//   let result = tpl.render(ctx)!
// ---------------------------------------------------------------------------
