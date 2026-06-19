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
pub fn registry(
  policy? : FsPolicy = FsPolicy::new(),
) -> @lepusa.CommandRegistry {
  register(@lepusa.CommandRegistry::new(), policy~)
}

///|
pub fn register(
  registry : @lepusa.CommandRegistry,
  policy? : FsPolicy = FsPolicy::new(),
) -> @lepusa.CommandRegistry {
  registry
  .register_async_fn("fs.readText", permission=FileSystemRead, handler=fn(
    payload,
  ) {
    handle_read_text(policy, payload)
  })
  .register_async_fn("fs.writeText", permission=FileSystemWrite, handler=fn(
    payload,
  ) {
    handle_write_text(policy, payload)
  })
  .register_async_fn("fs.exists", permission=FileSystemRead, handler=fn(
    payload,
  ) {
    handle_exists(policy, payload)
  })
  .register_async_fn("fs.createDir", permission=FileSystemWrite, handler=fn(
    payload,
  ) {
    handle_create_dir(policy, payload)
  })
  .register_async_fn("fs.readBytes", permission=FileSystemRead, handler=fn(
    payload,
  ) {
    handle_read_bytes(policy, payload)
  })
  .register_async_fn("fs.writeBytes", permission=FileSystemWrite, handler=fn(
    payload,
  ) {
    handle_write_bytes(policy, payload)
  })
  .register_async_fn("fs.list", permission=FileSystemRead, handler=fn(payload) {
    handle_list(policy, payload)
  })
  .register_async_fn("fs.metadata", permission=FileSystemRead, handler=fn(
    payload,
  ) {
    handle_metadata(policy, payload)
  })
  .register_async_fn("fs.delete", permission=FileSystemWrite, handler=fn(
    payload,
  ) {
    handle_delete(policy, payload)
  })
}

///|
fn handle_read_text(
  policy : FsPolicy,
  payload : String,
) -> Result[String, String] {
  match decode_path_payload(payload) {
    Ok((scope_name, path)) =>
      match policy.resolve(scope_name~, path~) {
        Ok(full_path) => {
          let content = @xfs.read_file_to_string(full_path) catch {
            _ => return Err("could not read filesystem path")
          }
          Ok(
            Json::object({
              "scope": Json::string(scope_name),
              "path": Json::string(path),
              "content": Json::string(content),
            }).stringify(),
          )
        }
        Err(problem) => Err(problem)
      }
    Err(problem) => Err(problem)
  }
}

///|
fn handle_write_text(
  policy : FsPolicy,
  payload : String,
) -> Result[String, String] {
  match decode_text_payload(payload) {
    Ok((scope_name, path, content)) =>
      match policy.resolve(scope_name~, path~, write=true) {
        Ok(full_path) => {
          @xfs.write_string_to_file(full_path, content) catch {
            _ => return Err("could not write filesystem path")
          }
          Ok(
            Json::object({
              "scope": Json::string(scope_name),
              "path": Json::string(path),
              "written": Json::boolean(true),
            }).stringify(),
          )
        }
        Err(problem) => Err(problem)
      }
    Err(problem) => Err(problem)
  }
}

///|
fn handle_exists(policy : FsPolicy, payload : String) -> Result[String, String] {
  match decode_path_payload(payload) {
    Ok((scope_name, path)) =>
      match policy.resolve(scope_name~, path~) {
        Ok(full_path) => {
          let exists = filesystem_path_exists(full_path)
          Ok(
            Json::object({
              "scope": Json::string(scope_name),
              "path": Json::string(path),
              "exists": Json::boolean(exists),
            }).stringify(),
          )
        }
        Err(problem) => Err(problem)
      }
    Err(problem) => Err(problem)
  }
}

///|
fn handle_create_dir(
  policy : FsPolicy,
  payload : String,
) -> Result[String, String] {
  match decode_path_payload(payload) {
    Ok((scope_name, path)) =>
      match policy.resolve(scope_name~, path~, write=true) {
        Ok(full_path) => {
          @xfs.create_dir(full_path) catch {
            _ =>
              if !filesystem_path_exists(full_path) {
                return Err("could not create filesystem directory")
              }
          }
          Ok(
            Json::object({
              "scope": Json::string(scope_name),
              "path": Json::string(path),
              "created": Json::boolean(true),
            }).stringify(),
          )
        }
        Err(problem) => Err(problem)
      }
    Err(problem) => Err(problem)
  }
}

///|
fn handle_read_bytes(
  policy : FsPolicy,
  payload : String,
) -> Result[String, String] {
  match decode_path_payload(payload) {
    Ok((scope_name, path)) =>
      match policy.resolve(scope_name~, path~) {
        Ok(full_path) => {
          let content = @xfs.read_file_to_bytes(full_path) catch {
            _ => return Err("could not read filesystem bytes")
          }
          Ok(
            Json::object({
              "scope": Json::string(scope_name),
              "path": Json::string(path),
              "base64": Json::string(@base64.encode(content.view())),
              "bytes": Json::number(
                content.length().to_double(),
                repr=content.length().to_string(),
              ),
            }).stringify(),
          )
        }
        Err(problem) => Err(problem)
      }
    Err(problem) => Err(problem)
  }
}

///|
fn handle_write_bytes(
  policy : FsPolicy,
  payload : String,
) -> Result[String, String] {
  match decode_bytes_payload(payload) {
    Ok((scope_name, path, content)) =>
      match policy.resolve(scope_name~, path~, write=true) {
        Ok(full_path) => {
          @xfs.write_bytes_to_file(full_path, content) catch {
            _ => return Err("could not write filesystem bytes")
          }
          Ok(
            Json::object({
              "scope": Json::string(scope_name),
              "path": Json::string(path),
              "written": Json::boolean(true),
              "bytes": Json::number(
                content.length().to_double(),
                repr=content.length().to_string(),
              ),
            }).stringify(),
          )
        }
        Err(problem) => Err(problem)
      }
    Err(problem) => Err(problem)
  }
}

///|
fn handle_list(policy : FsPolicy, payload : String) -> Result[String, String] {
  match decode_path_payload(payload) {
    Ok((scope_name, path)) =>
      match policy.resolve(scope_name~, path~) {
        Ok(full_path) => {
          let entries = @xfs.read_dir(full_path) catch {
            _ => return Err("could not list filesystem directory")
          }
          entries.sort()
          Ok(
            Json::object({
              "scope": Json::string(scope_name),
              "path": Json::string(path),
              "entries": Json::array(
                entries.map(fn(entry) { Json::string(entry) }),
              ),
            }).stringify(),
          )
        }
        Err(problem) => Err(problem)
      }
    Err(problem) => Err(problem)
  }
}

///|
fn handle_metadata(
  policy : FsPolicy,
  payload : String,
) -> Result[String, String] {
  match decode_path_payload(payload) {
    Ok((scope_name, path)) =>
      match policy.resolve(scope_name~, path~) {
        Ok(full_path) => {
          let exists = filesystem_path_exists(full_path)
          let is_dir = if exists {
            @xfs.is_dir(full_path) catch {
              _ => false
            }
          } else {
            false
          }
          let byte_count = if exists && !is_dir {
            let bytes = @xfs.read_file_to_bytes(full_path) catch {
              _ => Bytes::new(0)
            }
            bytes.length()
          } else {
            0
          }
          Ok(
            Json::object({
              "scope": Json::string(scope_name),
              "path": Json::string(path),
              "exists": Json::boolean(exists),
              "isDirectory": Json::boolean(is_dir),
              "isFile": Json::boolean(exists && !is_dir),
              "bytes": Json::number(
                byte_count.to_double(),
                repr=byte_count.to_string(),
              ),
            }).stringify(),
          )
        }
        Err(problem) => Err(problem)
      }
    Err(problem) => Err(problem)
  }
}

///|
fn handle_delete(policy : FsPolicy, payload : String) -> Result[String, String] {
  match decode_path_payload(payload) {
    Ok((scope_name, path)) =>
      match policy.resolve(scope_name~, path~, write=true) {
        Ok(full_path) => {
          let existed = filesystem_path_exists(full_path)
          if existed {
            let is_dir = @xfs.is_dir(full_path) catch { _ => false }
            if is_dir {
              @xfs.remove_dir(full_path) catch {
                _ => return Err("could not delete filesystem directory")
              }
            } else {
              @xfs.remove_file(full_path) catch {
                _ => return Err("could not delete filesystem file")
              }
            }
          }
          Ok(
            Json::object({
              "scope": Json::string(scope_name),
              "path": Json::string(path),
              "deleted": Json::boolean(existed),
            }).stringify(),
          )
        }
        Err(problem) => Err(problem)
      }
    Err(problem) => Err(problem)
  }
}

///|
fn decode_path_payload(payload : String) -> Result[(String, String), String] {
  match parse_payload(payload) {
    Ok(Object(object)) => {
      let scope_name = required_string_field(object, "scope")
      let path = required_string_field(object, "path")
      if scope_name == "" {
        Err("filesystem scope is required")
      } else {
        match validate_relative_path(path) {
          Some(problem) => Err(problem)
          None => Ok((scope_name, path))
        }
      }
    }
    Ok(_) => Err("filesystem path payload must be an object")
    Err(problem) => Err(problem)
  }
}

///|
fn decode_text_payload(
  payload : String,
) -> Result[(String, String, String), String] {
  match parse_payload(payload) {
    Ok(Object(object)) => {
      let scope_name = required_string_field(object, "scope")
      let path = required_string_field(object, "path")
      let content = required_string_field(object, "content")
      if scope_name == "" {
        Err("filesystem scope is required")
      } else {
        match validate_relative_path(path) {
          Some(problem) => Err(problem)
          None => Ok((scope_name, path, content))
        }
      }
    }
    Ok(_) => Err("filesystem text payload must be an object")
    Err(problem) => Err(problem)
  }
}

///|
fn decode_bytes_payload(
  payload : String,
) -> Result[(String, String, Bytes), String] {
  match parse_payload(payload) {
    Ok(Object(object)) => {
      let scope_name = required_string_field(object, "scope")
      let path = required_string_field(object, "path")
      let encoded = required_string_field(object, "base64")
      if scope_name == "" {
        Err("filesystem scope is required")
      } else if encoded == "" {
        Err("filesystem base64 content is required")
      } else {
        match validate_relative_path(path) {
          Some(problem) => Err(problem)
          None => {
            let content = @base64.decode(encoded) catch {
              _ => return Err("invalid filesystem base64 content")
            }
            Ok((scope_name, path, content))
          }
        }
      }
    }
    Ok(_) => Err("filesystem bytes payload must be an object")
    Err(problem) => Err(problem)
  }
}

///|
fn parse_payload(payload : String) -> Result[Json, String] {
  if payload == "" {
    return Err("filesystem payload is required")
  }
  try @json.parse(payload) catch {
    error => Err("invalid filesystem payload: \{error}")
  } noraise {
    json => Ok(json)
  }
}

///|
fn required_string_field(object : Map[String, Json], key : String) -> String {
  match object.get(key) {
    Some(String(value)) => value
    _ => ""
  }
}

///|
fn filesystem_path_exists(path : String) -> Bool {
  let is_dir = @xfs.is_dir(path) catch { _ => false }
  if is_dir {
    true
  } else {
    let _ = @xfs.read_file_to_bytes(path) catch { _ => return false }
    true
  }
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
