///|
fn project_capabilities_from_object(
  object : Map[String, Json],
  base_dir~ : String,
  problems : Array[String],
) -> Array[@lepusa.Capability] {
  let capabilities : Array[@lepusa.Capability] = []
  match optional_config_array(object, "capabilities") {
    Some(items) =>
      for item in items {
        match item {
          Object(capability_object) =>
            capabilities.push(
              capability_from_object(capability_object, base_dir~, problems),
            )
          _ => problems.push("project capabilities entries must be objects")
        }
      }
    None => ()
  }
  capabilities
}

///|
fn capability_from_object(
  object : Map[String, Json],
  base_dir~ : String,
  problems : Array[String],
) -> @lepusa.Capability {
  let name = required_config_string(object, "name", problems)
  let mut capability = @lepusa.Capability::new(name)
  match optional_config_array(object, "windows") {
    Some(windows) =>
      for window in windows {
        match window {
          String(label) => capability = capability.window(label)
          _ => problems.push("project capability windows must be strings")
        }
      }
    None => ()
  }
  match optional_config_array(object, "commands") {
    Some(commands) =>
      for command in commands {
        match command {
          String(route) => capability = capability.command(route)
          _ => problems.push("project capability commands must be strings")
        }
      }
    None => ()
  }
  match optional_config_array(object, "permissions") {
    Some(permissions) =>
      for permission in permissions {
        match permission {
          String(name) =>
            match permission_from_string(name, problems) {
              Some(permission) => capability = capability.permission(permission)
              None => ()
            }
          _ => problems.push("project capability permissions must be strings")
        }
      }
    None => ()
  }
  match optional_config_array(object, "scopes") {
    Some(scopes) =>
      for scope in scopes {
        match scope {
          Object(scope_object) =>
            capability = capability.operation_scope(
              operation_scope_from_object(scope_object, base_dir~, problems),
            )
          _ => problems.push("project capability scopes must be objects")
        }
      }
    None => ()
  }
  capability
}

///|
fn operation_scope_from_object(
  object : Map[String, Json],
  base_dir~ : String,
  problems : Array[String],
) -> @lepusa.OperationScope {
  match optional_config_string(object, "path") {
    Some(path) =>
      return @lepusa.OperationScope::path(
        root=config_path(base_dir, path),
        writable=optional_config_bool(object, "writable").unwrap_or(false),
      )
    None => ()
  }
  match optional_config_string(object, "shell") {
    Some(command) => return @lepusa.OperationScope::shell(command)
    None => ()
  }
  match optional_config_string(object, "url") {
    Some(origin) => return @lepusa.OperationScope::url(origin)
    None => ()
  }
  match optional_config_string(object, "kind") {
    Some(kind) => {
      let value = optional_config_string(object, "value").unwrap_or("")
      match kind {
        "path" =>
          @lepusa.OperationScope::path(
            root=config_path(
              base_dir,
              optional_config_string(object, "root").unwrap_or(value),
            ),
            writable=optional_config_bool(object, "writable").unwrap_or(false),
          )
        "shell" =>
          @lepusa.OperationScope::shell(
            optional_config_string(object, "command").unwrap_or(value),
          )
        "url" =>
          @lepusa.OperationScope::url(
            optional_config_string(object, "origin").unwrap_or(value),
          )
        _ => {
          problems.push("unknown project capability scope kind: \{kind}")
          @lepusa.OperationScope::shell("")
        }
      }
    }
    None => {
      problems.push("project capability scope kind is required")
      @lepusa.OperationScope::shell("")
    }
  }
}

///|
fn project_filesystem_scopes_from_object(
  object : Map[String, Json],
  base_dir~ : String,
  problems : Array[String],
) -> Array[@lepusa.FileSystemScope] {
  let scopes : Array[@lepusa.FileSystemScope] = []
  match optional_config_array(object, "filesystemScopes") {
    Some(items) =>
      for item in items {
        match item {
          Object(scope_object) =>
            scopes.push(
              filesystem_scope_from_object(scope_object, base_dir~, problems),
            )
          _ => problems.push("project filesystemScopes entries must be objects")
        }
      }
    None => ()
  }
  scopes
}

///|
fn filesystem_scope_from_object(
  object : Map[String, Json],
  base_dir~ : String,
  problems : Array[String],
) -> @lepusa.FileSystemScope {
  let name = required_config_string(object, "name", problems)
  let root = config_path(
    base_dir,
    required_config_string(object, "root", problems),
  )
  let writable = optional_config_bool(object, "writable").unwrap_or(false)
  @lepusa.FileSystemScope::new(name~, root~, writable~)
}

///|
fn permission_from_string(
  name : String,
  problems : Array[String],
) -> @lepusa.Permission? {
  match @lepusa.Permission::named(name) {
    Ok(permission) => Some(permission)
    Err(problem) => {
      problems.push(problem)
      None
    }
  }
}
