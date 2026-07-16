// ---------------------------------------------------------------------------
// MoonTera — Template Context
//
// Manages variable scopes with nested (parent) chains.
// Each template has one root Context; for-loops and macros push child scopes.
// ---------------------------------------------------------------------------

/// A template context with optional parent for nested scope chains.
pub struct Context {
  data : Map[String, Value]
  parent : Option[Context]
  macros : Map[String, MacroDef]
}

/// Create a new root context with an empty data map.
pub fn Context::new() -> Context {
  {
    data: Map::new(),
    parent: None,
    macros: Map::new(),
  }
}

/// Create a child context that delegates to `parent` for lookups.
pub fn Context::new_child(parent : Context) -> Context {
  {
    data: Map::new(),
    parent: Some(parent),
    macros: Map::new(),
  }
}

/// Look up a variable by name.
/// Walks up the parent chain until found; returns `None` if not found.
pub fn Context::get(self : Context, name : String) -> Option[Value] {
  match self.data.get(name) {
    Some(v) => Some(v)
    None => match self.parent {
      Some(p) => p.get(name)
      None => None
    }
  }
}

/// Set a variable in the **current** scope (does not walk up).
pub fn Context::set(self : Context, name : String, value : Value) -> Unit {
  self.data[name] = value
}

/// Insert a (key, value) pair into the **root** (outermost) scope.
pub fn Context::insert_global(self : Context, name : String, value : Value) -> Unit {
  match self.parent {
    Some(p) => p.insert_global(name, value)
    None => self.data[name] = value
  }
}

/// Check whether a variable is defined in any scope.
pub fn Context::contains(self : Context, name : String) -> Bool {
  match self.data.get(name) {
    Some(_) => true
    None => match self.parent {
      Some(p) => p.contains(name)
      None => false
    }
  }
}

/// Return true if this is a root context (no parent).
pub fn Context::is_root(self : Context) -> Bool {
  match self.parent {
    Some(_) => false
    None => true
  }
}

/// Look up a macro by name across the scope chain.
pub fn Context::get_macro(self : Context, name : String) -> Option[MacroDef] {
  match self.macros.get(name) {
    Some(m) => Some(m)
    None => match self.parent {
      Some(p) => p.get_macro(name)
      None => None
    }
  }
}

/// Register a macro in the current scope.
pub fn Context::set_macro(self : Context, m : MacroDef) -> Unit {
  self.macros[m.name] = m
}

/// Build a context from a Map (convenience for tests).
pub fn Context::from_map(map : Map[String, Value]) -> Context {
  {
    data: map,
    parent: None,
    macros: Map::new(),
  }
}
