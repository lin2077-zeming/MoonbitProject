// ---------------------------------------------------------------------------
// MoonTera — Filter System
// ---------------------------------------------------------------------------

/// A filter function signature.
pub type FilterFn = (Value, Array[Value]) -> Result[Value, String]

// ===========================================================================
// Filter Registry
// ===========================================================================

pub struct FilterRegistry {
  filters : Map[String, FilterFn]
}

pub fn FilterRegistry::new() -> FilterRegistry {
  { filters: Map::new() }
}

pub fn FilterRegistry::register(self : FilterRegistry, name : String, f : FilterFn) -> FilterRegistry {
  self.filters[name] = f
  self
}

pub fn FilterRegistry::get(self : FilterRegistry, name : String) -> Option[FilterFn] {
  self.filters.get(name)
}

// ===========================================================================
// Default registry with all built-in filters
// ===========================================================================

pub fn FilterRegistry::default() -> FilterRegistry {
  let mut r = FilterRegistry::new()
  r = r.register("upper", apply_upper)
  r = r.register("lower", apply_lower)
  r = r.register("capitalize", apply_capitalize)
  r = r.register("trim", apply_trim)
  r = r.register("length", apply_length)
  r = r.register("reverse", apply_reverse)
  r = r.register("first", apply_first)
  r = r.register("last", apply_last)
  r = r.register("join", apply_join)
  r = r.register("replace", apply_replace)
  r = r.register("default", apply_default)
  r = r.register("int", apply_to_int)
  r = r.register("string", apply_to_string)
  r
}

// ===========================================================================
// Filter function wrappers (match FilterFn signature)
// ===========================================================================

fn apply_upper(v : Value, _a : Array[Value]) -> Result[Value, String] { filter_upper(v) }
fn apply_lower(v : Value, _a : Array[Value]) -> Result[Value, String] { filter_lower(v) }
fn apply_capitalize(v : Value, _a : Array[Value]) -> Result[Value, String] { filter_capitalize(v) }
fn apply_trim(v : Value, _a : Array[Value]) -> Result[Value, String] { filter_trim(v) }
fn apply_length(v : Value, _a : Array[Value]) -> Result[Value, String] { filter_length(v) }
fn apply_reverse(v : Value, _a : Array[Value]) -> Result[Value, String] { filter_reverse(v) }
fn apply_first(v : Value, _a : Array[Value]) -> Result[Value, String] { filter_first(v) }
fn apply_last(v : Value, _a : Array[Value]) -> Result[Value, String] { filter_last(v) }
fn apply_join(v : Value, a : Array[Value]) -> Result[Value, String] { filter_join(v, a) }
fn apply_replace(v : Value, a : Array[Value]) -> Result[Value, String] { filter_replace(v, a) }
fn apply_default(v : Value, a : Array[Value]) -> Result[Value, String] { filter_default(v, a) }
fn apply_to_int(v : Value, _a : Array[Value]) -> Result[Value, String] { filter_to_int(v) }
fn apply_to_string(v : Value, _a : Array[Value]) -> Result[Value, String] { filter_to_string(v) }

// ===========================================================================
// Built-in filter implementations
// ===========================================================================

fn filter_upper(val : Value) -> Result[Value, String] {
  match val {
    Value::Str(s) => Ok(Value::Str(str_to_upper(s)))
    _ => Err("upper filter requires a string")
  }
}

fn filter_lower(val : Value) -> Result[Value, String] {
  match val {
    Value::Str(s) => Ok(Value::Str(str_to_lower(s)))
    _ => Err("lower filter requires a string")
  }
}

fn filter_capitalize(val : Value) -> Result[Value, String] {
  match val {
    Value::Str(s) => {
      if s.length() == 0 {
        Ok(Value::Str(""))
      } else {
        let first = s[0]
        let upper_first = char_to_upper(Int::unsafe_to_char(first.to_int()))
        Ok(Value::Str(upper_first.to_string() + s[1:s.length()].to_owned()))
      }
    }
    _ => Err("capitalize filter requires a string")
  }
}

fn filter_trim(val : Value) -> Result[Value, String] {
  match val {
    Value::Str(s) => Ok(Value::Str(str_trim(s)))
    _ => Err("trim filter requires a string")
  }
}

fn filter_length(val : Value) -> Result[Value, String] {
  match val {
    Value::Str(s) => Ok(Value::Int(s.length().to_int64()))
    Value::Array(arr) => Ok(Value::Int(arr.length().to_int64()))
    _ => Err("length filter requires a string or array")
  }
}

fn filter_reverse(val : Value) -> Result[Value, String] {
  match val {
    Value::Str(s) => Ok(Value::Str(str_reverse(s)))
    Value::Array(arr) => {
      let rev : Array[Value] = []
      let mut i = arr.length()
      while i > 0 {
        i = i - 1
        rev.push(arr[i])
      }
      Ok(Value::Array(rev))
    }
    _ => Err("reverse filter requires a string or array")
  }
}

fn filter_first(val : Value) -> Result[Value, String] {
  match val {
    Value::Str(s) => {
      if s.length() > 0 { Ok(Value::Str(Int::unsafe_to_char(s[0].to_int()).to_string())) }
      else { Ok(Value::Str("")) }
    }
    Value::Array(arr) => {
      if arr.length() > 0 { Ok(arr[0]) }
      else { Ok(Value::Null) }
    }
    _ => Err("first filter requires a string or array")
  }
}

fn filter_last(val : Value) -> Result[Value, String] {
  match val {
    Value::Str(s) => {
      if s.length() > 0 { Ok(Value::Str(Int::unsafe_to_char(s[s.length() - 1].to_int()).to_string())) }
      else { Ok(Value::Str("")) }
    }
    Value::Array(arr) => {
      if arr.length() > 0 { Ok(arr[arr.length() - 1]) }
      else { Ok(Value::Null) }
    }
    _ => Err("last filter requires a string or array")
  }
}

fn filter_join(val : Value, args : Array[Value]) -> Result[Value, String] {
  let sep = if args.length() > 0 {
    match args[0] {
      Value::Str(s) => s
      _ => ""
    }
  } else {
    ""
  }
  match val {
    Value::Array(arr) => {
      if arr.length() == 0 {
        Ok(Value::Str(""))
      } else {
        let mut result = arr[0].to_string()
        for i = 1; i < arr.length(); i = i + 1 {
          result = result + sep + arr[i].to_string()
        }
        Ok(Value::Str(result))
      }
    }
    _ => Err("join filter requires an array")
  }
}

fn filter_replace(val : Value, args : Array[Value]) -> Result[Value, String] {
  let from = if args.length() > 0 {
    match args[0] {
      Value::Str(s) => s
      _ => ""
    }
  } else { "" }
  let to = if args.length() > 1 {
    match args[1] {
      Value::Str(s) => s
      _ => ""
    }
  } else { "" }
  match val {
    Value::Str(s) => Ok(Value::Str(str_replace(s, from, to)))
    _ => Err("replace filter requires a string")
  }
}

fn filter_default(val : Value, args : Array[Value]) -> Result[Value, String] {
  let should_default = match val {
    Value::Null => true
    Value::Str(s) => s == ""
    Value::Array(arr) => arr.length() == 0
    _ => false
  }
  if should_default {
    if args.length() > 0 { Ok(args[0]) }
    else { Ok(Value::Str("")) }
  } else {
    Ok(val)
  }
}

fn filter_to_int(val : Value) -> Result[Value, String] {
  match val {
    Value::Int(_) => Ok(val)
    Value::Float(f) => Ok(Value::Int(f.to_int64()))
    Value::Str(s) => match parse_str_to_int64(s) {
      Some(n) => Ok(Value::Int(n))
      None => Err("Cannot convert string to int: " + s)
    }
    Value::Bool(b) => Ok(Value::Int(if b { 1L } else { 0L }))
    _ => Err("Cannot convert to int")
  }
}

fn filter_to_string(val : Value) -> Result[Value, String] {
  Ok(Value::Str(val.to_string()))
}

// ===========================================================================
// String utility functions
// ===========================================================================

fn str_to_upper(s : String) -> String {
  let mut result = ""
  for i = 0; i < s.length(); i = i + 1 {
    result = result + char_to_upper(Int::unsafe_to_char(s[i].to_int())).to_string()
  }
  result
}

fn str_to_lower(s : String) -> String {
  let mut result = ""
  for i = 0; i < s.length(); i = i + 1 {
    result = result + char_to_lower(Int::unsafe_to_char(s[i].to_int())).to_string()
  }
  result
}

fn str_trim(s : String) -> String {
  let len = s.length()
  let mut start = 0
  while start < len {
    let c = s[start]
    if c == ' ' || c == '\t' || c == '\n' || c == '\r' {
      start = start + 1
    } else { break }
  }
  let mut end = len
  while end > start {
    let c = s[end - 1]
    if c == ' ' || c == '\t' || c == '\n' || c == '\r' {
      end = end - 1
    } else { break }
  }
  if start >= end { "" } else { s[start:end].to_owned() }
}

fn str_reverse(s : String) -> String {
  let mut result = ""
  let mut i = s.length()
  while i > 0 {
    i = i - 1
    result = result + Int::unsafe_to_char(s[i].to_int()).to_string()
  }
  result
}

fn str_replace(s : String, from : String, to : String) -> String {
  if from == "" { return s }
  let mut result = ""
  let mut i = 0
  while i < s.length() {
    let mut match_found = false
    if i + from.length() <= s.length() {
      match_found = true
      for j = 0; j < from.length(); j = j + 1 {
        if s[i + j] != from[j] {
          match_found = false
          break
        }
      }
    }
    if match_found {
      result = result + to
      i = i + from.length()
    } else {
      result = result + Int::unsafe_to_char(s[i].to_int()).to_string()
      i = i + 1
    }
  }
  result
}

fn char_to_upper(c : Char) -> Char {
  if c >= 'a' && c <= 'z' { Int::unsafe_to_char(c.to_int() - 32) } else { c }
}

fn char_to_lower(c : Char) -> Char {
  if c >= 'A' && c <= 'Z' { Int::unsafe_to_char(c.to_int() + 32) } else { c }
}

fn parse_str_to_int64(s : String) -> Option[Int64] {
  if s.length() == 0 { return None }
  let mut result = 0L
  for i = 0; i < s.length(); i = i + 1 {
    let c = s[i]
    if c >= '0' && c <= '9' {
      let digit = c.to_int() - '0'.to_int()
      result = result * 10L + digit.to_int64()
    } else {
      return None
    }
  }
  Some(result)
}
