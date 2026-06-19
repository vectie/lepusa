///|
pub struct FileSystemScope {
  name : String
  root : String
  writable : Bool
} derive(Debug, Eq)

///|
pub fn FileSystemScope::new(
  name~ : String,
  root~ : String,
  writable? : Bool = false,
) -> FileSystemScope {
  { name, root, writable }
}

///|
pub fn FileSystemScope::name(self : FileSystemScope) -> String {
  self.name
}

///|
pub fn FileSystemScope::root(self : FileSystemScope) -> String {
  self.root
}

///|
pub fn FileSystemScope::writable(self : FileSystemScope) -> Bool {
  self.writable
}

///|
pub fn FileSystemScope::validate(self : FileSystemScope) -> Array[String] {
  let problems : Array[String] = []
  if self.name == "" {
    problems.push("filesystem scope name is required")
  }
  if self.root == "" {
    problems.push("filesystem scope root is required")
  }
  if self.name.contains("/") || self.name.contains("\\") {
    problems.push("filesystem scope name must not contain path separators")
  }
  problems
}

///|
pub fn FileSystemScope::to_json(self : FileSystemScope) -> String {
  [
    "{",
    "\"name\":\{self.name.json_string()},",
    "\"root\":\{self.root.json_string()},",
    "\"writable\":\{self.writable.json_bool()}",
    "}",
  ].join("")
}
