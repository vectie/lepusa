///|
pub struct FileDialogDefaultDirectory {
  name : String
  scope_name : String
  path : String
} derive(Debug, Eq)

///|
pub struct FileDialogPolicy {
  default_directories : Array[FileDialogDefaultDirectory]
} derive(Debug, Eq)

///|
pub fn FileDialogDefaultDirectory::new(
  name~ : String,
  scope_name~ : String,
  path? : String = ".",
) -> FileDialogDefaultDirectory {
  { name, scope_name, path }
}

///|
pub fn FileDialogDefaultDirectory::name(
  self : FileDialogDefaultDirectory,
) -> String {
  self.name
}

///|
pub fn FileDialogDefaultDirectory::scope_name(
  self : FileDialogDefaultDirectory,
) -> String {
  self.scope_name
}

///|
pub fn FileDialogDefaultDirectory::path(
  self : FileDialogDefaultDirectory,
) -> String {
  self.path
}

///|
pub fn FileDialogDefaultDirectory::validate(
  self : FileDialogDefaultDirectory,
) -> Array[String] {
  let problems : Array[String] = []
  if self.name == "" {
    problems.push("file dialog default directory name is required")
  }
  if self.scope_name == "" {
    problems.push("file dialog default directory scope is required")
  }
  match validate_relative_path(self.path) {
    Some(problem) => problems.push(problem)
    None => ()
  }
  problems
}

///|
pub fn FileDialogPolicy::new(
  default_directories? : Array[FileDialogDefaultDirectory] = [],
) -> FileDialogPolicy {
  { default_directories, }
}

///|
pub fn FileDialogPolicy::default_directory(
  self : FileDialogPolicy,
  directory : FileDialogDefaultDirectory,
) -> FileDialogPolicy {
  let directories = self.default_directories.copy()
  directories.push(directory)
  { default_directories: directories }
}

///|
pub fn FileDialogPolicy::default_directories(
  self : FileDialogPolicy,
) -> Array[FileDialogDefaultDirectory] {
  self.default_directories.copy()
}

///|
pub fn FileDialogPolicy::validate(self : FileDialogPolicy) -> Array[String] {
  let problems : Array[String] = []
  let seen : Array[String] = []
  for directory in self.default_directories {
    problems.append(directory.validate())
    let name = directory.name()
    if name != "" {
      if seen.contains(name) {
        problems.push("file dialog default directory must be unique: \{name}")
      } else {
        seen.push(name)
      }
    }
  }
  problems
}

///|
pub fn FileDialogPolicy::validate_scopes(
  self : FileDialogPolicy,
  scopes : Array[@lepusa.FileSystemScope],
) -> Array[String] {
  let problems = self.validate()
  for directory in self.default_directories {
    if directory.scope_name() != "" &&
      !has_scope(scopes, directory.scope_name()) {
      problems.push(
        "unknown file dialog default directory scope: \{directory.scope_name()}",
      )
    }
  }
  problems
}

///|
fn has_scope(scopes : Array[@lepusa.FileSystemScope], name : String) -> Bool {
  for scope in scopes {
    if scope.name() == name {
      return true
    }
  }
  false
}

///|
pub fn plugin() -> @lepusa.Plugin {
  @lepusa.Plugin::new("fileDialog")
  .command_async("openFile", permission=FileDialog)
  .command_async("openFiles", permission=FileDialog)
  .command_async("openDirectory", permission=FileDialog)
  .command_async("saveFile", permission=FileDialog)
}

///|
pub fn capability(name? : String = "file-dialog") -> @lepusa.Capability {
  @lepusa.Capability::new(name).permission(FileDialog)
}

///|
pub fn capability_for_window(
  window_label : String,
  name? : String = "file-dialog",
) -> @lepusa.Capability {
  capability(name~).window(window_label)
}

///|
fn validate_relative_path(path : String) -> String? {
  if path == "" {
    return Some("file dialog default directory path is required")
  }
  if path == "." {
    return None
  }
  if path.has_prefix("/") || path.has_prefix("\\") {
    return Some("file dialog default directory path must be relative")
  }
  for segment in path.split("/") {
    if segment == "" || segment == "." || segment == ".." {
      return Some("unsafe file dialog default directory path: \{path}")
    }
    if segment.contains("\\") {
      return Some("unsafe file dialog default directory path: \{path}")
    }
  }
  None
}
