// Copyright (c) 2024 LinZeming
// Released under the MIT License
//
// TemplateLoader — resolves template names to source strings.
//
// For now this is a simple in-memory registry.  File-system loading
// will be added later.

// ---------------------------------------------------------------------------
// TemplateLoader
// ---------------------------------------------------------------------------

///|
/// A simple in-memory template source registry.
pub(all) struct TemplateLoader {
  sources : Map[String, String]
}

///|
/// Create an empty loader.
pub fn TemplateLoader::new() -> TemplateLoader {
  {
    sources: Map::new(),
  }
}

///|
/// Register a named template source.
pub fn TemplateLoader::add(
  self : TemplateLoader,
  name : String,
  source : String
) -> TemplateLoader {
  let sources = self.sources
  sources[name] = source
  { sources: sources }
}

///|
/// Look up a template source by name.
pub fn TemplateLoader::get(self : TemplateLoader, name : String) -> String? {
  for key in self.sources.keys() {
    if key == name {
      return Some(self.sources[key])
    }
  }
  None
}
