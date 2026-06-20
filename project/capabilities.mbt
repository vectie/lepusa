///|
fn project_capabilities_from_object(
  object : Map[String, Json],
  problems : Array[String],
) -> Array[@lepusa.Capability] {
  let capabilities : Array[@lepusa.Capability] = []
  match optional_config_array(object, "capabilities") {
    Some(items) =>
      for item in items {
        match item {
          Object(capability_object) =>
            capabilities.push(
              capability_from_object(capability_object, problems),
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
  capability
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
