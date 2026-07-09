// Email template example — macros, includes, and custom filters.

fn main {
  // Define a macro-based email layout with includes.
  let email_source = #|{% macro button(text, url) %}
<a href="{{ url }}" style="padding:12px 24px;background:#4A90D9;color:white;text-decoration:none;border-radius:6px">{{ text | upper }}</a>
{% endmacro %}

{% include "header" %}

<h1>{{ subject }}</h1>
<p>Hello {{ user_name }},</p>

{{ body }}

{% if cta_url != "" %}
  {{ button(cta_text, cta_url) }}
{% endif %}

{% include "footer" %}|#

  let tpl = match @template.Template::parse(email_source) {
    Ok(t) => t
    Err(err) => { println(err.to_string()); return }
  }

  // Set up a template loader for include partials.
  let loader = @template.TemplateLoader::new()
    .add("header", "<div style=\"font-family:Arial;max-width:600px;margin:0 auto\">")
    .add("footer", "<hr><p style=\"color:#999;font-size:12px\">© 2026 Acme Corp. All rights reserved.</p></div>")

  let ctx = @template.Context::new()
    .set("subject", @template.Value::Str("Your Order Confirmation"))
    .set("user_name", @template.Value::Str("Alice"))
    .set("body", @template.Value::Str("Thank you for your order! Your items will ship within 2-3 business days."))
    .set("cta_text", @template.Value::Str("View Order"))
    .set("cta_url", @template.Value::Str("https://example.com/orders/12345"))

  match tpl.render_with_loader(ctx, loader) {
    Ok(html) => println(html)
    Err(err) => println("Render error: " + err.to_string())
  }
}
