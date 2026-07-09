// Copyright (c) 2024 LinZeming
// Released under the MIT License
//
// Filters — built-in filter functions and registry for the template engine.
//
// Filters are functions `(Value, Array[Value]) -> Result[Value, String]`
// registered by name.  Chain them with `|` in templates:
//   `{{ name | upper | trim }}`

// ---------------------------------------------------------------------------
// Filter type
// ---------------------------------------------------------------------------

/// A filter function: takes the input value and optional arguments,
/// returns the filtered value or an error.
type FilterFn = (Value, Array[Value]) -> Result[Value, String]

// ---------------------------------------------------------------------------
// Filter registry
// ---------------------------------------------------------------------------

/// Registry mapping filter names to their implementations.
pub(all) struct FilterRegistry {
  filters : Map[String, FilterFn]
}

/// Create an empty registry.
pub fn FilterRegistry::new() -> FilterRegistry {
  {
    filters: Map::new(),
  }
}

/// Register a filter function under *name*.
pub fn FilterRegistry::register(
  self : FilterRegistry,
  name : String,
  f : FilterFn
) -> FilterRegistry {
  let filters = self.filters
  filters[name] = f
  { filters: filters }
}

/// Look up a filter by name.
pub fn FilterRegistry::lookup(self : FilterRegistry, name : String) -> FilterFn? {
  for key in self.filters.keys() {
    if key == name {
      return Some(self.filters[key])
    }
  }
  None
}

///|
/// Create a registry pre-populated with all built-in filters.
pub fn FilterRegistry::default() -> FilterRegistry {
  FilterRegistry::new()
    .register("upper", filter_upper)
    .register("lower", filter_lower)
    .register("capitalize", filter_capitalize)
    .register("trim", filter_trim)
    .register("length", filter_length)
    .register("reverse", filter_reverse)
    .register("first", filter_first)
    .register("last", filter_last)
    .register("join", filter_join)
    .register("replace", filter_replace)
    .register("default", filter_default)
    .register("int", filter_int)
    .register("string", filter_string)
}

// ---------------------------------------------------------------------------
// String helpers
// ---------------------------------------------------------------------------

/// Extract a single character as a 1-char string via slicing.
fn char_slice(s : String, i : Int) -> String {
  if i >= 0 && i < s.length() {
    s[i:i + 1].to_owned()
  } else {
    ""
  }
}

/// Simple string replace.
fn string_replace(s : String, from : String, to : String) -> String {
  if from == "" {
    return s
  }
  let mut result = ""
  let mut i = 0
  let s_len = s.length()
  let from_len = from.length()
  while i < s_len {
    if i + from_len <= s_len {
      let mut matches = true
      let mut j = 0
      while j < from_len {
        if s[i + j] != from[j] {
          matches = false
          break
        }
        j = j + 1
      }
      if matches {
        result = result + to
        i = i + from_len
        continue
      }
    }
    result = result + char_slice(s, i)
    i = i + 1
  }
  result
}

/// Trim leading and trailing whitespace.
fn string_trim(s : String) -> String {
  let len = s.length()
  let mut start = 0
  while start < len {
    let c = s[start].to_int()
    if c == 32 || c == 9 || c == 13 || c == 10 {
      start = start + 1
    } else {
      break
    }
  }
  let mut end = len
  while end > start {
    let c = s[end - 1].to_int()
    if c == 32 || c == 9 || c == 13 || c == 10 {
      end = end - 1
    } else {
      break
    }
  }
  s[start:end].to_owned()
}

/// Parse a string to Int64.
fn filter_parse_int(s : String) -> Result[Int64, String] {
  if s.length() == 0 {
    return Err("empty")
  }
  let mut result = 0L
  let mut i = 0
  let len = s.length()
  let zero = '0'.to_int()
  while i < len {
    let ch = s[i].to_int()
    if ch >= zero && ch <= '9'.to_int() {
      let digit = (ch - zero).to_int64()
      result = result * 10L + digit
    } else {
      return Err("invalid character")
    }
    i = i + 1
  }
  Ok(result)
}

// ---------------------------------------------------------------------------
// Built-in filters
// ---------------------------------------------------------------------------

/// `upper` — convert string to uppercase.
fn filter_upper(value : Value, _args : Array[Value]) -> Result[Value, String] {
  match value {
    Str(s) => Ok(Str(s.to_upper()))
    _ => Err("filter 'upper' expects a string, got: " + value.type_name())
  }
}

/// `lower` — convert string to lowercase.
fn filter_lower(value : Value, _args : Array[Value]) -> Result[Value, String] {
  match value {
    Str(s) => Ok(Str(s.to_lower()))
    _ => Err("filter 'lower' expects a string, got: " + value.type_name())
  }
}

/// `capitalize` — uppercase the first character.
fn filter_capitalize(value : Value, _args : Array[Value]) -> Result[Value, String] {
  match value {
    Str(s) => {
      if s.length() == 0 {
        Ok(Str(""))
      } else {
        let first = char_slice(s, 0)
        let rest = if s.length() > 1 { s[1:s.length()].to_owned() } else { "" }
        Ok(Str(first.to_upper() + rest))
      }
    }
    _ => Err("filter 'capitalize' expects a string, got: " + value.type_name())
  }
}

/// `trim` — remove leading and trailing whitespace.
fn filter_trim(value : Value, _args : Array[Value]) -> Result[Value, String] {
  match value {
    Str(s) => Ok(Str(string_trim(s)))
    _ => Err("filter 'trim' expects a string, got: " + value.type_name())
  }
}

/// `length` — return the length of a string, array, or object.
fn filter_length(value : Value, _args : Array[Value]) -> Result[Value, String] {
  match value {
    Str(s) => Ok(Int(s.length().to_int64()))
    Array(arr) => Ok(Int(arr.length().to_int64()))
    Object(m) => Ok(Int(m.length().to_int64()))
    _ => Err("filter 'length' expects string, array, or object")
  }
}

/// `reverse` — reverse a string or array.
fn filter_reverse(value : Value, _args : Array[Value]) -> Result[Value, String] {
  match value {
    Str(s) => {
      let len = s.length()
      let mut result = ""
      let mut i = len
      while i > 0 {
        i = i - 1
        result = result + char_slice(s, i)
      }
      Ok(Str(result))
    }
    Array(arr) => {
      let len = arr.length()
      let result : Array[Value] = Array::new()
      let mut i = len
      while i > 0 {
        i = i - 1
        result.push(arr[i])
      }
      Ok(Array(result))
    }
    _ => Err("filter 'reverse' expects a string or array")
  }
}

/// `first` — return the first character / element.
fn filter_first(value : Value, _args : Array[Value]) -> Result[Value, String] {
  match value {
    Str(s) => {
      if s.length() == 0 {
        Ok(Str(""))
      } else {
        Ok(Str(char_slice(s, 0)))
      }
    }
    Array(arr) => {
      if arr.length() == 0 {
        Ok(Array([]))
      } else {
        Ok(arr[0])
      }
    }
    _ => Err("filter 'first' expects a string or array")
  }
}

/// `last` — return the last character / element.
fn filter_last(value : Value, _args : Array[Value]) -> Result[Value, String] {
  match value {
    Str(s) => {
      let len = s.length()
      if len == 0 {
        Ok(Str(""))
      } else {
        Ok(Str(char_slice(s, len - 1)))
      }
    }
    Array(arr) => {
      let len = arr.length()
      if len == 0 {
        Ok(Array([]))
      } else {
        Ok(arr[len - 1])
      }
    }
    _ => Err("filter 'last' expects a string or array")
  }
}

/// `join(sep)` — join array elements with separator.
fn filter_join(value : Value, args : Array[Value]) -> Result[Value, String] {
  match value {
    Array(arr) => {
      let sep = if args.length() > 0 { args[0].to_string() } else { "" }
      if arr.length() == 0 {
        return Ok(Str(""))
      }
      let mut result = arr[0].to_string()
      for i = 1; i < arr.length(); i = i + 1 {
        result = result + sep + arr[i].to_string()
      }
      Ok(Str(result))
    }
    _ => Err("filter 'join' expects an array")
  }
}

/// `replace(from, to)` — replace substrings.
fn filter_replace(value : Value, args : Array[Value]) -> Result[Value, String] {
  match value {
    Str(s) => {
      if args.length() < 2 {
        return Err("filter 'replace' expects 2 arguments: from, to")
      }
      let from = args[0].to_string()
      let to = args[1].to_string()
      Ok(Str(string_replace(s, from, to)))
    }
    _ => Err("filter 'replace' expects a string")
  }
}

/// `default(val)` — return default if value is falsy.
fn filter_default(value : Value, args : Array[Value]) -> Result[Value, String] {
  if value.is_truthy() {
    Ok(value)
  } else {
    if args.length() > 0 {
      Ok(args[0])
    } else {
      Ok(Str(""))
    }
  }
}

/// `int` — convert to integer.
fn filter_int(value : Value, _args : Array[Value]) -> Result[Value, String] {
  match value {
    Int(_) => Ok(value)
    Float(f) => Ok(Int(f.to_int64()))
    Str(s) => match filter_parse_int(s) {
      Ok(i) => Ok(Int(i))
      Err(_) => Err("filter 'int': cannot parse '" + s + "' as integer")
    }
    Bool(b) => Ok(Int(if b { 1L } else { 0L }))
    _ => Err("filter 'int' cannot convert type: " + value.type_name())
  }
}

/// `string` — convert to string.
fn filter_string(value : Value, _args : Array[Value]) -> Result[Value, String] {
  Ok(Str(value.to_string()))
}
