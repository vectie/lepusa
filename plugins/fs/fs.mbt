///|
pub struct FsPolicy {
  scopes : Array[@lepusa.FileSystemScope]
} derive(Debug, Eq)

///|
pub fn FsPolicy::new(scopes? : Array[@lepusa.FileSystemScope] = []) -> FsPolicy {
  { scopes, }
}

///|
pub fn FsPolicy::scope(
  self : FsPolicy,
  scope : @lepusa.FileSystemScope,
) -> FsPolicy {
  let scopes = self.scopes.copy()
  scopes.push(scope)
  { scopes, }
}

///|
pub fn FsPolicy::scopes(self : FsPolicy) -> Array[@lepusa.FileSystemScope] {
  self.scopes.copy()
}

///|
pub fn FsPolicy::validate(self : FsPolicy) -> Array[String] {
  let problems : Array[String] = []
  let seen : Array[String] = []
  for scope in self.scopes {
    problems.append(scope.validate())
    let name = scope.name()
    if name != "" {
      if seen.contains(name) {
        problems.push("filesystem scope must be unique: \{name}")
      } else {
        seen.push(name)
      }
    }
  }
  problems
}

///|
pub fn FsPolicy::resolve(
  self : FsPolicy,
  scope_name~ : String,
  path~ : String,
  write? : Bool = false,
) -> Result[String, String] {
  match self.find_scope(scope_name) {
    None => Err("unknown filesystem scope: \{scope_name}")
    Some(scope) =>
      if write && !scope.writable() {
        Err("filesystem scope is read-only: \{scope_name}")
      } else {
        match validate_relative_path(path) {
          Some(problem) => Err(problem)
          None => Ok(join_path(scope.root(), path))
        }
      }
  }
}

///|
fn FsPolicy::find_scope(
  self : FsPolicy,
  name : String,
) -> @lepusa.FileSystemScope? {
  for scope in self.scopes {
    if scope.name() == name {
      return Some(scope)
    }
  }
  None
}

///|
pub fn plugin() -> @lepusa.Plugin {
  @lepusa.Plugin::new("fs")
  .command_async("readText", permission=FileSystemRead)
  .command_async("readBytes", permission=FileSystemRead)
  .command_async("exists", permission=FileSystemRead)
  .command_async("list", permission=FileSystemRead)
  .command_async("metadata", permission=FileSystemRead)
  .command_async("writeText", permission=FileSystemWrite)
  .command_async("writeBytes", permission=FileSystemWrite)
  .command_async("delete", permission=FileSystemWrite)
  .command_async("createDir", permission=FileSystemWrite)
}

///|
pub fn read_capability(name? : String = "fs-read") -> @lepusa.Capability {
  @lepusa.Capability::new(name).permission(FileSystemRead)
}

///|
pub fn write_capability(name? : String = "fs-write") -> @lepusa.Capability {
  @lepusa.Capability::new(name).permission(FileSystemWrite)
}

///|
pub fn read_capability_for_window(
  window_label : String,
  name? : String = "fs-read",
) -> @lepusa.Capability {
  read_capability(name~).window(window_label)
}

///|
pub fn write_capability_for_window(
  window_label : String,
  name? : String = "fs-write",
) -> @lepusa.Capability {
  write_capability(name~).window(window_label)
}

///|
pub fn read_write_capability(
  name? : String = "fs-read-write",
) -> @lepusa.Capability {
  @lepusa.Capability::new(name)
  .permission(FileSystemRead)
  .permission(FileSystemWrite)
}

///|
pub fn read_write_capability_for_window(
  window_label : String,
  name? : String = "fs-read-write",
) -> @lepusa.Capability {
  read_write_capability(name~).window(window_label)
}

///|
fn validate_relative_path(path : String) -> String? {
  if path == "" {
    return Some("filesystem path is required")
  }
  if path.has_prefix("/") || path.has_prefix("\\") {
    return Some("filesystem path must be relative")
  }
  for segment in path.split("/") {
    if segment == "" || segment == "." || segment == ".." {
      return Some("unsafe filesystem path: \{path}")
    }
    if segment.contains("\\") {
      return Some("unsafe filesystem path: \{path}")
    }
  }
  None
}

///|
fn join_path(root : String, path : String) -> String {
  let root = root.trim_end(chars="/\\").to_owned()
  if root == "" {
    path
  } else {
    "\{root}/\{path}"
  }
}
