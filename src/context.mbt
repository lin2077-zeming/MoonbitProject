// Copyright (c) 2024 LinZeming
// Released under the MIT License
//
// Context — nested-scope variable storage for template rendering.
//
// Contexts form a linked list (via `parent`).  Variable lookup walks the
// chain from innermost to outermost scope.  `set` always writes to the
// current (innermost) scope.

// ---------------------------------------------------------------------------
// Context struct
// ---------------------------------------------------------------------------

///|
/// A rendering context — stores variables in a nested-scope chain.
pub(all) struct Context {
  data : Map[String, Value]
  parent : Option[Context]
} derive(Debug)

// ---------------------------------------------------------------------------
// Constructors
// ---------------------------------------------------------------------------

///|
/// Create an empty root context.
pub fn Context::new() -> Context {
  {
    data: Map::new(),
    parent: Option::None,
  }
}

///|
/// Create a child context that delegates lookups to *parent*.
pub fn Context::new_child(parent : Context) -> Context {
  {
    data: Map::new(),
    parent: Option::Some(parent),
  }
}

// ---------------------------------------------------------------------------
// Variable access
// ---------------------------------------------------------------------------

///|
/// Check whether *name* is defined in **this** scope (does not recurse).
fn Context::has_own(self : Context, name : String) -> Bool {
  for key in self.data.keys() {
    if key == name {
      return true
    }
  }
  false
}

///|
/// Look up *name* in the scope chain (current → parent → …).
/// Returns `Option::None` when the variable is not defined in any scope.
pub fn Context::get(self : Context, name : String) -> Option[Value] {
  if self.has_own(name) {
    Option::Some(self.data[name])
  } else {
    match self.parent {
      Option::Some(p) => p.get(name)
      Option::None => Option::None
    }
  }
}

///|
/// Set *name* = *value* in the **current** scope (does not affect parent).
pub fn Context::set(self : Context, name : String, value : Value) -> Context {
  let data = self.data
  data[name] = value
  { ..self, data }
}
