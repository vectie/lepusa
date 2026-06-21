///|
pub struct BundledRuntime {
  manifest : BundledRuntimeManifest
  registry : @lepusa.CommandRegistry
}

///|
pub fn BundledRuntime::new(manifest : BundledRuntimeManifest) -> BundledRuntime {
  let registry = manifest.command_registry()
  { manifest, registry }
}

///|
pub fn BundledRuntime::manifest(
  self : BundledRuntime,
) -> BundledRuntimeManifest {
  self.manifest
}

///|
pub fn BundledRuntimeManifest::dispatch_json(
  self : BundledRuntimeManifest,
  id~ : String,
  window_label~ : String,
  route~ : String,
  payload? : String = "",
  origin? : String = "",
) -> String {
  BundledRuntime::new(self).dispatch_json(
    id~,
    window_label~,
    route~,
    payload~,
    origin~,
  )
}

///|
pub async fn BundledRuntimeManifest::dispatch_json_async(
  self : BundledRuntimeManifest,
  id~ : String,
  window_label~ : String,
  route~ : String,
  payload? : String = "",
  origin? : String = "",
) -> String {
  BundledRuntime::new(self).dispatch_json_async(
    id~,
    window_label~,
    route~,
    payload~,
    origin~,
  )
}

///|
pub fn BundledRuntime::dispatch_json(
  self : BundledRuntime,
  id~ : String,
  window_label~ : String,
  route~ : String,
  payload? : String = "",
  origin? : String = "",
) -> String {
  match self.dispatch(id~, window_label~, route~, payload~, origin~) {
    Ok(response) => @runtime.encode_invoke_response_json(response)
    Err(response) => @runtime.encode_invoke_response_json(response)
  }
}

///|
pub async fn BundledRuntime::dispatch_json_async(
  self : BundledRuntime,
  id~ : String,
  window_label~ : String,
  route~ : String,
  payload? : String = "",
  origin? : String = "",
) -> String {
  match self.dispatch_async(id~, window_label~, route~, payload~, origin~) {
    Ok(response) => @runtime.encode_invoke_response_json(response)
    Err(response) => @runtime.encode_invoke_response_json(response)
  }
}

///|
fn BundledRuntime::dispatch(
  self : BundledRuntime,
  id~ : String,
  window_label~ : String,
  route~ : String,
  payload~ : String,
  origin~ : String,
) -> Result[@lepusa.InvokeResponse, @lepusa.InvokeResponse] {
  match parse_invoke_route(route) {
    Ok((plugin, command)) => {
      match self.authorize_route(id~, window_label~, route~, origin~) {
        Some(response) => return Err(response)
        None => ()
      }
      let request = @lepusa.InvokeRequest::new(
        id~,
        window_label~,
        plugin~,
        command~,
        payload~,
        origin~,
      )
      let capability = @lepusa.Capability::new("bundled")
        .window(window_label)
        .command(route)
      Ok(
        self.registry.dispatch_with_permission(
          request,
          permission=@lepusa.Permission::command(route),
          capabilities=[capability],
        ),
      )
    }
    Err(problem) => Err(@lepusa.InvokeResponse::invalid_request(id, problem))
  }
}

///|
async fn BundledRuntime::dispatch_async(
  self : BundledRuntime,
  id~ : String,
  window_label~ : String,
  route~ : String,
  payload~ : String,
  origin~ : String,
) -> Result[@lepusa.InvokeResponse, @lepusa.InvokeResponse] {
  match parse_invoke_route(route) {
    Ok((plugin, command)) => {
      match self.authorize_route(id~, window_label~, route~, origin~) {
        Some(response) => return Err(response)
        None => ()
      }
      let request = @lepusa.InvokeRequest::new(
        id~,
        window_label~,
        plugin~,
        command~,
        payload~,
        origin~,
      )
      let capability = @lepusa.Capability::new("bundled")
        .window(window_label)
        .command(route)
      Ok(
        self.registry.dispatch_with_permission_async(
          request,
          permission=@lepusa.Permission::command(route),
          capabilities=[capability],
        ),
      )
    }
    Err(problem) => Err(@lepusa.InvokeResponse::invalid_request(id, problem))
  }
}

///|
fn BundledRuntime::authorize_route(
  self : BundledRuntime,
  id~ : String,
  window_label~ : String,
  route~ : String,
  origin~ : String,
) -> @lepusa.InvokeResponse? {
  if !self.registered_routes().contains(route) {
    Some(@lepusa.InvokeResponse::unknown_command(id, route))
  } else if !self.window_allows_route(window_label~, route~, origin~) {
    Some(@lepusa.InvokeResponse::permission_denied(id, route))
  } else {
    None
  }
}

///|
fn BundledRuntime::registered_routes(self : BundledRuntime) -> Array[String] {
  self.manifest.registered_routes()
}

///|
fn BundledRuntime::window_allows_route(
  self : BundledRuntime,
  window_label~ : String,
  route~ : String,
  origin? : String = "",
) -> Bool {
  self.manifest.window_allows_route(window_label~, route~, origin~)
}

///|
fn BundledRuntimeManifest::command_registry(
  self : BundledRuntimeManifest,
) -> @lepusa.CommandRegistry {
  let scopes = self.filesystem_scopes()
  let mut registry = @lepusa.CommandRegistry::new()
  for plugin_name in @catalog.registered_plugin_names() {
    registry = @catalog.register_with_filesystem_scopes(
      registry,
      plugin_name,
      scopes~,
    )
  }
  registry
}

///|
pub fn BundledRuntimeManifest::registered_routes(
  self : BundledRuntimeManifest,
) -> Array[String] {
  strings_from_json_array(
    optional_array(self.runtime, "registeredRoutes").unwrap_or([]),
  )
}

///|
pub fn BundledRuntimeManifest::registered_sync_routes(
  self : BundledRuntimeManifest,
) -> Array[String] {
  self.registered_routes_by_mode(self.command_registry().sync_routes())
}

///|
pub fn BundledRuntimeManifest::registered_async_routes(
  self : BundledRuntimeManifest,
) -> Array[String] {
  self.registered_routes_by_mode(self.command_registry().async_routes())
}

///|
fn BundledRuntimeManifest::registered_routes_by_mode(
  self : BundledRuntimeManifest,
  mode_routes : Array[String],
) -> Array[String] {
  let routes : Array[String] = []
  for route in self.registered_routes() {
    if mode_routes.contains(route) {
      routes.push(route)
    }
  }
  routes.sort()
  routes
}

///|
fn BundledRuntimeManifest::window_allows_route(
  self : BundledRuntimeManifest,
  window_label~ : String,
  route~ : String,
  origin? : String = "",
) -> Bool {
  match self.command_manifest_allows_route(window_label~, route~, origin~) {
    Some(allowed) => return allowed
    None => ()
  }
  for item in optional_array(self.runtime, "webviews").unwrap_or([]) {
    match item {
      Object(webview) =>
        if optional_string(webview, "label").unwrap_or("") == window_label {
          return strings_from_json_array(
            optional_array(webview, "allowedRoutes").unwrap_or([]),
          ).contains(route)
        }
      _ => ()
    }
  }
  false
}

///|
fn BundledRuntimeManifest::command_manifest_allows_route(
  self : BundledRuntimeManifest,
  window_label~ : String,
  route~ : String,
  origin~ : String,
) -> Bool? {
  match optional_object(self.runtime, "commandManifest") {
    None => None
    Some(manifest) =>
      match optional_array(manifest, "commands") {
        None => None
        Some(commands) => {
          for item in commands {
            match item {
              Object(command) =>
                if optional_string(command, "route").unwrap_or("") == route {
                  let windows = strings_from_json_array(
                    optional_array(command, "allowedWindows").unwrap_or([]),
                  )
                  let origins = strings_from_json_array(
                    optional_array(command, "allowedOrigins").unwrap_or([]),
                  )
                  return Some(
                    windows.contains(window_label) &&
                    (origins.is_empty() || origins.contains(origin)),
                  )
                }
              _ => ()
            }
          }
          Some(false)
        }
      }
  }
}

///|
fn BundledRuntimeManifest::filesystem_scopes(
  self : BundledRuntimeManifest,
) -> Array[@lepusa.FileSystemScope] {
  let scopes : Array[@lepusa.FileSystemScope] = []
  for item in optional_array(self.runtime, "filesystemScopes").unwrap_or([]) {
    match item {
      Object(scope) => {
        let name = optional_string(scope, "name").unwrap_or("")
        let root = optional_string(scope, "root").unwrap_or("")
        let writable = optional_bool(scope, "writable").unwrap_or(false)
        if name != "" && root != "" {
          scopes.push(@lepusa.FileSystemScope::new(name~, root~, writable~))
        }
      }
      _ => ()
    }
  }
  scopes
}

///|
fn parse_invoke_route(route : String) -> Result[(String, String), String] {
  let mut plugin = ""
  let mut command = ""
  let mut found_separator = false
  for char in route {
    if !found_separator && char == '.' {
      found_separator = true
    } else if found_separator {
      command = command + char.to_string()
    } else {
      plugin = plugin + char.to_string()
    }
  }
  if plugin == "" || command == "" {
    Err("invoke route must be <plugin.command>")
  } else {
    Ok((plugin, command))
  }
}

///|
fn strings_from_json_array(items : Array[Json]) -> Array[String] {
  let strings : Array[String] = []
  for item in items {
    match item {
      String(value) => strings.push(value)
      _ => ()
    }
  }
  strings
}
