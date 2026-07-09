// Copyright (c) 2024 LinZeming
// Released under the MIT License
//
// MoonTera CLI — command-line template rendering tool.
//
// Usage:
//   mbtemplate render "<template>" [--data '<json>']
//   mbtemplate check  "<template>"
//   mbtemplate --version | --help

fn main {
  let args = @env.args()
  if args.length() < 2 {
    print_help()
    return
  }

  let cmd = args[1]
  match cmd {
    "render" => cmd_render(args)
    "check" => cmd_check(args)
    "--version" | "-V" => print_version()
    "--help" | "-h" => print_help()
    _ => {
      @prelude.println("Unknown command: " + cmd)
      @prelude.println("Run 'mbtemplate --help' for usage.")
    }
  }
}

// ---------------------------------------------------------------------------
// Commands
// ---------------------------------------------------------------------------

fn cmd_render(args : Array[String]) {
  let mut template_src = ""
  let mut data_json = "{}"
  let mut i = 2
  while i < args.length() {
    let arg = args[i]
    if arg == "--data" || arg == "-d" {
      if i + 1 < args.length() {
        i = i + 1
        data_json = args[i]
      }
    } else if has_prefix(arg, "--data=") {
      data_json = arg_slice(arg, 7, arg.length())
    } else if !has_prefix(arg, "-") {
      template_src = arg
    }
    i = i + 1
  }

  if template_src == "" {
    @prelude.println("Error: No template provided.")
    return
  }

  // Parse JSON data.
  let val = match parse_json(data_json) {
    Ok(v) => v
    Err(msg) => {
      @prelude.println("JSON error: " + msg)
      return
    }
  }

  // Build context from JSON object.
  let ctx = match val {
    @tpl.Value::Object(m) => {
      let mut c = @tpl.Context::new()
      for key in m.keys() {
        c = c.set(key, m[key])
      }
      c
    }
    _ => {
      @prelude.println("Error: JSON data must be an object {...}")
      return
    }
  }

  // Parse and render template.
  match @tpl.Template::parse(template_src) {
    Ok(tpl) => match tpl.render(ctx) {
      Ok(output) => @prelude.println(output)
      Err(err) => @prelude.println(err.to_string())
    }
    Err(err) => @prelude.println(err.to_string())
  }
}

fn cmd_check(args : Array[String]) {
  let mut template_src = ""
  let mut i = 2
  while i < args.length() {
    if !has_prefix(args[i], "-") {
      template_src = args[i]
      break
    }
    i = i + 1
  }
  if template_src == "" {
    @prelude.println("Error: No template provided.")
    return
  }
  match @tpl.Template::parse(template_src) {
    Ok(_) => @prelude.println("OK — template syntax is valid.")
    Err(err) => @prelude.println(err.to_string())
  }
}

// ---------------------------------------------------------------------------
// Help & version
// ---------------------------------------------------------------------------

fn print_version() {
  @prelude.println("mbtemplate v" + @tpl.VERSION + " — MoonTera Template Engine")
}

fn print_help() {
  @prelude.println(#|MoonTera CLI — command-line template rendering tool.

Usage:
  mbtemplate render "<template>" [--data '<json>']
  mbtemplate check  "<template>"
  mbtemplate --version
  mbtemplate --help

Commands:
  render    Render a template with optional JSON context data.
  check     Check template syntax without rendering.
  --version Show version information.
  --help    Show this help message.

Examples:
  mbtemplate render "Hello, {{ name }}!" --data '{"name":"MoonBit"}'
  mbtemplate render "{{ x + y }}"         --data '{"x":1,"y":2}'
  mbtemplate check  "{% if x %}ok{% endif %}"
|#)
}

// ---------------------------------------------------------------------------
// Minimal JSON parser
// ---------------------------------------------------------------------------

fn parse_json(input : String) -> Result[@tpl.Value, String] {
  let pos = skip_ws(input, 0)
  if pos >= input.length() {
    return Err("empty input")
  }
  let (val, _) = parse_value(input, pos)
  Ok(val)
}

fn skip_ws(s : String, i : Int) -> Int {
  let mut pos = i
  let len = s.length()
  while pos < len {
    let c = s[pos].to_int()
    if c == 32 || c == 9 || c == 10 || c == 13 {
      pos = pos + 1
    } else {
      break
    }
  }
  pos
}

fn parse_value(s : String, i : Int) -> (@tpl.Value, Int) {
  let pos = skip_ws(s, i)
  if pos >= s.length() {
    return (@tpl.Value::Null, pos)
  }
  match s[pos].to_int() {
    123 => parse_object(s, pos)     // '{'
    91  => parse_array(s, pos)      // '['
    34  => parse_string(s, pos)     // '"'
    _ => {
      let ch = s[pos].to_int()
      if ch == 't'.to_int() || ch == 'f'.to_int() {
        parse_bool(s, pos)
      } else if ch == 'n'.to_int() {
        parse_null(s, pos)
      } else {
        parse_number(s, pos)
      }
    }
  }
}

fn parse_object(s : String, i : Int) -> (@tpl.Value, Int) {
  let mut pos = i + 1 // skip '{'
  let m : Map[String, @tpl.Value] = Map::new()
  pos = skip_ws(s, pos)
  if pos < s.length() && s[pos].to_int() == 125 {
    return (@tpl.Value::Object(m), pos + 1)
  }
  while true {
    pos = skip_ws(s, pos)
    let (kv, after_k) = parse_string(s, pos)
    let key = match kv {
      @tpl.Value::Str(k) => k
      _ => return abort_json("object key must be string")
    }
    pos = skip_ws(s, after_k)
    if pos >= s.length() || s[pos].to_int() != 58 {
      return abort_json("expected ':' in object")
    }
    pos = pos + 1
    let (val, after_v) = parse_value(s, pos)
    m[key] = val
    pos = skip_ws(s, after_v)
    if pos >= s.length() {
      return abort_json("unterminated object")
    }
    let term = s[pos].to_int()
    if term == 125 {
      return (@tpl.Value::Object(m), pos + 1)
    }
    if term == 44 {
      pos = pos + 1
    }
  }
  abort_json("unreachable")
}

fn parse_array(s : String, i : Int) -> (@tpl.Value, Int) {
  let mut pos = i + 1
  let arr : Array[@tpl.Value] = Array::new()
  pos = skip_ws(s, pos)
  if pos < s.length() && s[pos].to_int() == 93 {
    return (@tpl.Value::Array(arr), pos + 1)
  }
  while true {
    let (val, after_v) = parse_value(s, pos)
    arr.push(val)
    pos = skip_ws(s, after_v)
    if pos >= s.length() {
      return abort_json("unterminated array")
    }
    let term = s[pos].to_int()
    if term == 93 {
      return (@tpl.Value::Array(arr), pos + 1)
    }
    if term == 44 {
      pos = pos + 1
    }
  }
  abort_json("unreachable")
}

fn parse_string(s : String, i : Int) -> (@tpl.Value, Int) {
  let mut pos = i + 1
  let mut result = ""
  let len = s.length()
  while pos < len {
    let ch = s[pos].to_int()
    if ch == 92 { // backslash
      pos = pos + 1
      if pos >= len {
        return abort_json("unterminated string escape")
      }
      let esc = s[pos].to_int()
      if esc == 34 { result = result + "\"" }
      else if esc == 92 { result = result + "\\" }
      else if esc == 47 { result = result + "/" }
      else if esc == 110 { result = result + "\n" }
      else if esc == 116 { result = result + "\t" }
      else if esc == 114 { result = result + "\r" }
      else {
        result = result + s[pos:pos + 1].to_owned()
      }
      pos = pos + 1
    } else if ch == 34 {
      return (@tpl.Value::Str(result), pos + 1)
    } else {
      result = result + s[pos:pos + 1].to_owned()
      pos = pos + 1
    }
  }
  abort_json("unterminated string")
}

fn parse_bool(s : String, i : Int) -> (@tpl.Value, Int) {
  if i + 4 <= s.length() && s[i:i + 4].to_owned() == "true" {
    (@tpl.Value::Bool(true), i + 4)
  } else if i + 5 <= s.length() && s[i:i + 5].to_owned() == "false" {
    (@tpl.Value::Bool(false), i + 5)
  } else {
    abort_json("invalid boolean")
  }
}

fn parse_null(s : String, i : Int) -> (@tpl.Value, Int) {
  if i + 4 <= s.length() && s[i:i + 4].to_owned() == "null" {
    (@tpl.Value::Null, i + 4)
  } else {
    abort_json("invalid null")
  }
}

fn parse_number(s : String, i : Int) -> (@tpl.Value, Int) {
  let mut pos = i
  let len = s.length()
  let mut is_float = false
  if pos < len {
    let ch = s[pos].to_int()
    if ch == 45 || ch == 43 { pos = pos + 1 }
  }
  while pos < len && is_digit_char(s[pos]) { pos = pos + 1 }
  if pos < len && s[pos].to_int() == 46 {
    is_float = true
    pos = pos + 1
    while pos < len && is_digit_char(s[pos]) { pos = pos + 1 }
  }
  if pos < len {
    let ch = s[pos].to_int()
    if ch == 101 || ch == 69 {
      is_float = true
      pos = pos + 1
      if pos < len {
        let sign = s[pos].to_int()
        if sign == 43 || sign == 45 { pos = pos + 1 }
      }
      while pos < len && is_digit_char(s[pos]) { pos = pos + 1 }
    }
  }
  let num_str = s[i:pos].to_owned()
  if is_float {
    match parse_double(num_str) {
      Ok(f) => (@tpl.Value::Float(f), pos)
      Err(_) => abort_json("invalid number: " + num_str)
    }
  } else {
    match parse_int(num_str) {
      Ok(n) => (@tpl.Value::Int(n), pos)
      Err(_) => abort_json("invalid number: " + num_str)
    }
  }
}

fn is_digit_char(ch : UInt16) -> Bool {
  let c = ch.to_int()
  c >= 48 && c <= 57
}

// ---------------------------------------------------------------------------
// Number parsing (for JSON)
// ---------------------------------------------------------------------------

fn parse_int(s : String) -> Result[Int64, String] {
  if s.length() == 0 { return Err("empty") }
  let mut result = 0L
  let mut i = 0
  let len = s.length()
  let mut sign = 1L
  if i < len && s[i].to_int() == 45 { sign = -1L; i = i + 1 }
  while i < len {
    let ch = s[i].to_int()
    if ch >= 48 && ch <= 57 {
      result = result * 10L + (ch - 48).to_int64()
    } else {
      return Err("invalid")
    }
    i = i + 1
  }
  Ok(sign * result)
}

fn parse_double(s : String) -> Result[Double, String] {
  if s.length() == 0 { return Err("empty") }
  let mut i = 0
  let len = s.length()
  let mut sign = 1.0
  if i < len && s[i].to_int() == 45 { sign = -1.0; i = i + 1 }
  let mut result = 0.0
  while i < len {
    let ch = s[i].to_int()
    if ch >= 48 && ch <= 57 {
      result = result * 10.0 + (ch - 48).to_double()
      i = i + 1
    } else {
      break
    }
  }
  if i < len && s[i].to_int() == 46 {
    i = i + 1
    let mut frac = 0.1
    while i < len {
      let ch = s[i].to_int()
      if ch >= 48 && ch <= 57 {
        result = result + (ch - 48).to_double() * frac
        frac = frac * 0.1
        i = i + 1
      } else {
        break
      }
    }
  }
  Ok(sign * result)
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

fn abort_json(msg : String) -> (@tpl.Value, Int) {
  @prelude.abort("JSON parse error: " + msg)
}

fn has_prefix(s : String, prefix : String) -> Bool {
  if s.length() < prefix.length() { return false }
  let mut i = 0
  while i < prefix.length() {
    if s[i] != prefix[i] { return false }
    i = i + 1
  }
  true
}

fn arg_slice(s : String, start : Int, end : Int) -> String {
  s[start:end].to_owned()
}

