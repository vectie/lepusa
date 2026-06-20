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
) -> String {
  BundledRuntime::new(self).dispatch_json(id~, window_label~, route~, payload~)
}

///|
pub async fn BundledRuntimeManifest::dispatch_json_async(
  self : BundledRuntimeManifest,
  id~ : String,
  window_label~ : String,
  route~ : String,
  payload? : String = "",
) -> String {
  BundledRuntime::new(self).dispatch_json_async(
    id~,
    window_label~,
    route~,
    payload~,
  )
}

///|
pub fn BundledRuntime::dispatch_json(
  self : BundledRuntime,
  id~ : String,
  window_label~ : String,
  route~ : String,
  payload? : String = "",
) -> String {
  match self.dispatch(id~, window_label~, route~, payload~) {
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
) -> String {
  match self.dispatch_async(id~, window_label~, route~, payload~) {
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
) -> Result[@lepusa.InvokeResponse, @lepusa.InvokeResponse] {
  match parse_invoke_route(route) {
    Ok((plugin, command)) => {
      if !self.registered_routes().contains(route) {
        return Err(
          @lepusa.InvokeResponse::error(id, "unknown command: \{route}"),
        )
      }
      if !self.window_allows_route(window_label~, route~) {
        return Err(
          @lepusa.InvokeResponse::error(id, "permission denied: \{route}"),
        )
      }
      let request = @lepusa.InvokeRequest::new(
        id~,
        window_label~,
        plugin~,
        command~,
        payload~,
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
    Err(problem) => Err(@lepusa.InvokeResponse::error(id, problem))
  }
}

///|
async fn BundledRuntime::dispatch_async(
  self : BundledRuntime,
  id~ : String,
  window_label~ : String,
  route~ : String,
  payload~ : String,
) -> Result[@lepusa.InvokeResponse, @lepusa.InvokeResponse] {
  match parse_invoke_route(route) {
    Ok((plugin, command)) => {
      if !self.registered_routes().contains(route) {
        return Err(
          @lepusa.InvokeResponse::error(id, "unknown command: \{route}"),
        )
      }
      if !self.window_allows_route(window_label~, route~) {
        return Err(
          @lepusa.InvokeResponse::error(id, "permission denied: \{route}"),
        )
      }
      let request = @lepusa.InvokeRequest::new(
        id~,
        window_label~,
        plugin~,
        command~,
        payload~,
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
    Err(problem) => Err(@lepusa.InvokeResponse::error(id, problem))
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
) -> Bool {
  self.manifest.window_allows_route(window_label~, route~)
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
) -> Bool {
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
