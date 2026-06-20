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
priv struct FileDialogRequest {
  default_directory : String
  path : String
  suggested_name : String
}

///|
pub fn registry(
  policy? : FileDialogPolicy = FileDialogPolicy::new(),
  scopes? : Array[@lepusa.FileSystemScope] = [],
) -> @lepusa.CommandRegistry {
  register(@lepusa.CommandRegistry::new(), policy~, scopes~)
}

///|
pub fn register(
  registry : @lepusa.CommandRegistry,
  policy? : FileDialogPolicy = FileDialogPolicy::new(),
  scopes? : Array[@lepusa.FileSystemScope] = [],
) -> @lepusa.CommandRegistry {
  registry
  .register_async_fn("fileDialog.openFile", permission=FileDialog, handler=payload => {
    handle_picker(
      policy,
      scopes,
      payload,
      action="openFile",
      multiple=false,
      directory=false,
      save=false,
    )
  })
  .register_async_fn("fileDialog.openFiles", permission=FileDialog, handler=payload => {
    handle_picker(
      policy,
      scopes,
      payload,
      action="openFiles",
      multiple=true,
      directory=false,
      save=false,
    )
  })
  .register_async_fn("fileDialog.openDirectory", permission=FileDialog, handler=payload => {
    handle_picker(
      policy,
      scopes,
      payload,
      action="openDirectory",
      multiple=false,
      directory=true,
      save=false,
    )
  })
  .register_async_fn("fileDialog.saveFile", permission=FileDialog, handler=payload => {
    handle_picker(
      policy,
      scopes,
      payload,
      action="saveFile",
      multiple=false,
      directory=false,
      save=true,
    )
  })
}

///|
async fn handle_picker(
  policy : FileDialogPolicy,
  scopes : Array[@lepusa.FileSystemScope],
  payload : String,
  action~ : String,
  multiple~ : Bool,
  directory~ : Bool,
  save~ : Bool,
) -> Result[String, String] {
  @async.sleep(0)
  let request = match
    decode_request_payload(payload, context="file dialog \{action}") {
    Ok(request) => request
    Err(problem) => return Err(problem)
  }
  match resolve_default_directory(policy, scopes, request.default_directory) {
    Ok(default_directory) =>
      Ok(
        Json::object({
          "action": Json::string(action),
          "status": Json::string("delegated"),
          "multiple": Json::boolean(multiple),
          "directory": Json::boolean(directory),
          "save": Json::boolean(save),
          "defaultDirectory": default_directory,
          "path": Json::string(request.path),
          "suggestedName": Json::string(request.suggested_name),
        }).stringify(),
      )
    Err(problem) => Err(problem)
  }
}

///|
fn decode_request_payload(
  payload : String,
  context~ : String,
) -> Result[FileDialogRequest, String] {
  if payload == "" {
    return Ok({ default_directory: "", path: "", suggested_name: "" })
  }
  let json = @json.parse(payload) catch {
    error => return Err("invalid \{context} payload: \{error}")
  }
  match json {
    String(default_directory) =>
      Ok({ default_directory, path: "", suggested_name: "" })
    Object(object) => {
      let default_directory = string_field(object, "defaultDirectory").unwrap_or(
        string_field(object, "directory").unwrap_or(""),
      )
      let path = string_field(object, "path").unwrap_or("")
      let suggested_name = string_field(object, "suggestedName").unwrap_or(
        string_field(object, "filename").unwrap_or(""),
      )
      match validate_optional_relative_path(path, context~, field="path") {
        Some(problem) => Err(problem)
        None =>
          match
            validate_optional_relative_path(
              suggested_name,
              context~,
              field="suggestedName",
            ) {
            Some(problem) => Err(problem)
            None => Ok({ default_directory, path, suggested_name })
          }
      }
    }
    _ => Err("\{context} payload must be a string or object")
  }
}

///|
fn resolve_default_directory(
  policy : FileDialogPolicy,
  scopes : Array[@lepusa.FileSystemScope],
  name : String,
) -> Result[Json, String] {
  if name == "" {
    return Ok(Json::null())
  }
  match default_directory_by_name(policy.default_directories(), name) {
    Some(directory) =>
      match scope_by_name(scopes, directory.scope_name()) {
        Some(scope) =>
          Ok(
            Json::object({
              "name": Json::string(directory.name()),
              "scope": Json::string(scope.name()),
              "root": Json::string(scope.root()),
              "path": Json::string(directory.path()),
              "resolvedPath": Json::string(
                join_scope_path(scope.root(), directory.path()),
              ),
              "writable": Json::boolean(scope.writable()),
            }),
          )
        None =>
          Err(
            "unknown file dialog default directory scope: \{directory.scope_name()}",
          )
      }
    None => Err("file dialog default directory not found: \{name}")
  }
}

///|
fn default_directory_by_name(
  directories : Array[FileDialogDefaultDirectory],
  name : String,
) -> FileDialogDefaultDirectory? {
  for directory in directories {
    if directory.name() == name {
      return Some(directory)
    }
  }
  None
}

///|
fn scope_by_name(
  scopes : Array[@lepusa.FileSystemScope],
  name : String,
) -> @lepusa.FileSystemScope? {
  for scope in scopes {
    if scope.name() == name {
      return Some(scope)
    }
  }
  None
}

///|
fn validate_optional_relative_path(
  path : String,
  context~ : String,
  field~ : String,
) -> String? {
  if path == "" {
    return None
  }
  match validate_relative_path(path) {
    Some(problem) => Some("\{context} \{field}: \{problem}")
    None => None
  }
}

///|
fn join_scope_path(root : String, path : String) -> String {
  if path == "." {
    root
  } else if root.has_suffix("/") {
    "\{root}\{path}"
  } else {
    "\{root}/\{path}"
  }
}

///|
fn string_field(object : Map[String, Json], key : String) -> String? {
  match object.get(key) {
    Some(String(value)) => Some(value)
    _ => None
  }
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
