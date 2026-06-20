///|
pub struct ProjectConfig {
  manifest : @lepusa.ProjectManifest
  root : @lepusa.Cell
  registry : @lepusa.CommandRegistry
}

///|
pub fn ProjectConfig::manifest(self : ProjectConfig) -> @lepusa.ProjectManifest {
  self.manifest
}

///|
pub fn ProjectConfig::root(self : ProjectConfig) -> @lepusa.Cell {
  self.root
}

///|
pub fn ProjectConfig::registry(self : ProjectConfig) -> @lepusa.CommandRegistry {
  self.registry
}

///|
pub fn ProjectConfig::parse(
  text : String,
  base_dir? : String = ".",
) -> Result[ProjectConfig, Array[String]] {
  let json = @json.parse(text) catch {
    error => return Err(["invalid project config json: \{error}"])
  }
  match json {
    Object(object) => loaded_project_from_object(object, base_dir~)
    _ => Err(["project config must be a json object"])
  }
}

///|
fn loaded_project_from_object(
  object : Map[String, Json],
  base_dir~ : String,
) -> Result[ProjectConfig, Array[String]] {
  let problems : Array[String] = []
  let identifier = required_config_string(object, "identifier", problems)
  let product_name = required_config_string(object, "productName", problems)
  let version = required_config_string(object, "version", problems)
  let root_html = optional_config_string(object, "rootHtml").unwrap_or(
    "<main>Hello Lepusa</main>",
  )
  let icon_path = optional_config_string(object, "icon").map(fn(path) {
    config_path(base_dir, path)
  })
  let signing = match optional_config_object(object, "signing") {
    Some(signing_object) =>
      signing_config_from_object(signing_object, base_dir~, problems)
    None => @lepusa.SigningConfig::new()
  }
  let root = @lepusa.simple_cell(@lepusa.Html::text(root_html))
  let runtime = match optional_config_object(object, "runtime") {
    Some(runtime_object) => runtime_config_from_object(runtime_object, problems)
    None => @lepusa.RuntimeConfig::system_webview()
  }
  let windows = project_windows_from_object(object, base_dir~, problems)
  let plugins = project_plugins_from_object(object, problems)
  let capabilities = project_capabilities_from_object(object, problems)
  let filesystem_scopes = project_filesystem_scopes_from_object(
    object,
    base_dir~,
    problems,
  )
  let startup = project_startup_from_object(object, base_dir~, problems)
  let lifecycle_hooks = project_lifecycle_from_object(
    object,
    base_dir~,
    problems,
  )
  if problems.is_empty() {
    let mut manifest = @lepusa.ProjectManifest::new(
      @lepusa.AppMetadata::new(identifier~, product_name~, version~),
      runtime~,
    )
    manifest = manifest.with_startup(startup)
    for window in windows {
      manifest = manifest.with_window(window)
    }
    for plugin in plugins {
      manifest = manifest.with_plugin(plugin)
    }
    for capability in capabilities {
      manifest = manifest.with_capability(capability)
    }
    for scope in filesystem_scopes {
      manifest = manifest.with_file_system_scope(scope)
    }
    for hook in lifecycle_hooks {
      manifest = manifest.with_lifecycle(hook.event(), hook.command())
    }
    match icon_path {
      Some(icon_path) => manifest = manifest.with_icon_path(icon_path)
      None => ()
    }
    manifest = manifest.with_signing(signing)
    let registry = project_registry_from_plugins(plugins, filesystem_scopes~)
    Ok({ manifest, root, registry })
  } else {
    Err(problems)
  }
}

///|
fn signing_config_from_object(
  object : Map[String, Json],
  base_dir~ : String,
  problems : Array[String],
) -> @lepusa.SigningConfig {
  let identity = optional_config_string(object, "identity")
  let team_id = optional_config_string(object, "teamId")
  let entitlements_path = optional_config_string(object, "entitlements").map(fn(
    path,
  ) {
    config_path(base_dir, path)
  })
  let notarization_profile = optional_config_string(
    object, "notarizationProfile",
  )
  let timestamp_url = optional_config_string(object, "timestampUrl")
  let signing = @lepusa.SigningConfig::new(
    identity?,
    entitlements_path?,
    team_id?,
    notarization_profile?,
    timestamp_url?,
  )
  for problem in signing.validate() {
    problems.push(problem)
  }
  signing
}

///|
fn project_registry_from_plugins(
  plugins : Array[@lepusa.Plugin],
  filesystem_scopes~ : Array[@lepusa.FileSystemScope],
) -> @lepusa.CommandRegistry {
  let mut registry = @lepusa.CommandRegistry::new()
  for plugin in plugins {
    registry = @catalog.register_with_filesystem_scopes(
      registry,
      plugin.name(),
      scopes=filesystem_scopes,
    )
  }
  registry
}

///|
fn project_windows_from_object(
  object : Map[String, Json],
  base_dir~ : String,
  problems : Array[String],
) -> Array[@lepusa.WindowConfig] {
  match optional_config_array(object, "windows") {
    Some(items) => {
      let windows : Array[@lepusa.WindowConfig] = []
      for item in items {
        match item {
          Object(window_object) =>
            windows.push(
              window_config_from_object(window_object, base_dir~, problems),
            )
          _ => problems.push("project windows entries must be objects")
        }
      }
      windows
    }
    None =>
      match optional_config_object(object, "window") {
        Some(window_object) =>
          [window_config_from_object(window_object, base_dir~, problems)]
        None => {
          problems.push("project window is required")
          []
        }
      }
  }
}

///|
fn project_plugins_from_object(
  object : Map[String, Json],
  problems : Array[String],
) -> Array[@lepusa.Plugin] {
  let plugins : Array[@lepusa.Plugin] = []
  match optional_config_array(object, "plugins") {
    Some(items) =>
      for item in items {
        match item {
          Object(plugin_object) =>
            plugins.push(plugin_from_object(plugin_object, problems))
          _ => problems.push("project plugins entries must be objects")
        }
      }
    None => ()
  }
  plugins
}

///|
fn plugin_from_object(
  object : Map[String, Json],
  problems : Array[String],
) -> @lepusa.Plugin {
  let name = required_config_string(object, "name", problems)
  let mut plugin = @lepusa.Plugin::new(name)
  match optional_config_array(object, "commands") {
    Some(commands) =>
      for command in commands {
        plugin = plugin_command_from_json(plugin, command, problems)
      }
    None =>
      match official_plugin_from_name(name) {
        Some(official) => plugin = official
        None => ()
      }
  }
  plugin
}

///|
fn official_plugin_from_name(name : String) -> @lepusa.Plugin? {
  @catalog.plugin(name)
}

///|
fn plugin_command_from_json(
  plugin : @lepusa.Plugin,
  json : Json,
  problems : Array[String],
) -> @lepusa.Plugin {
  match json {
    String(name) => plugin.command_sync(name)
    Object(object) => {
      let name = required_config_string(object, "name", problems)
      let mode = optional_config_string(object, "mode").unwrap_or("sync")
      let permission = command_permission_from_object(
        object,
        route="\{plugin.name()}.\{name}",
        problems,
      )
      match mode {
        "sync" => plugin.command_sync(name, permission?)
        "async" => plugin.command_async(name, permission?)
        "stream" => plugin.command_stream(name, permission?)
        "event" => plugin.command_event(name, permission?)
        value => {
          problems.push("unknown plugin command mode: \{value}")
          plugin.command_sync(name, permission?)
        }
      }
    }
    _ => {
      problems.push("project plugin commands must be strings or objects")
      plugin
    }
  }
}

///|
fn command_permission_from_object(
  object : Map[String, Json],
  route~ : String,
  problems : Array[String],
) -> @lepusa.Permission? {
  match optional_config_string(object, "permission") {
    Some(name) =>
      match permission_from_string(name, problems) {
        Some(permission) => Some(permission)
        None => Some(@lepusa.Permission::command(route))
      }
    None => None
  }
}

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

///|
fn runtime_config_from_object(
  object : Map[String, Json],
  problems : Array[String],
) -> @lepusa.RuntimeConfig {
  let backend = optional_config_string(object, "backend").unwrap_or(
    "system-webview",
  )
  let devtools = optional_config_bool(object, "devtools").unwrap_or(false)
  let asset_protocol = optional_config_string(object, "assetProtocol").unwrap_or(
    "lepusa",
  )
  match backend {
    "system-webview" =>
      @lepusa.RuntimeConfig::system_webview(devtools~, asset_protocol~)
    "headless" => @lepusa.RuntimeConfig::headless()
    value => {
      problems.push("unknown runtime backend: \{value}")
      @lepusa.RuntimeConfig::system_webview()
    }
  }
}

///|
fn window_config_from_object(
  object : Map[String, Json],
  base_dir~ : String,
  problems : Array[String],
) -> @lepusa.WindowConfig {
  let label = optional_config_string(object, "label").unwrap_or("main")
  let title = optional_config_string(object, "title").unwrap_or("Lepusa")
  let width = optional_config_int(object, "width").unwrap_or(1000)
  let height = optional_config_int(object, "height").unwrap_or(720)
  let resizable = optional_config_bool(object, "resizable").unwrap_or(true)
  let window = @lepusa.WindowConfig::new(
    label~,
    title~,
    width~,
    height~,
    resizable~,
  )
  match optional_config_object(object, "source") {
    Some(source_object) =>
      window.with_source(source_from_object(source_object, base_dir~, problems))
    None => window
  }
}

///|
fn source_from_object(
  object : Map[String, Json],
  base_dir~ : String,
  problems : Array[String],
) -> @lepusa.Source {
  match optional_config_string(object, "html") {
    Some(html) => return @lepusa.Source::html(html)
    None => ()
  }
  match optional_config_string(object, "localPath") {
    Some(path) => return @lepusa.Source::local_path(config_path(base_dir, path))
    None => ()
  }
  match optional_config_string(object, "packaged") {
    Some(path) => return @lepusa.Source::packaged(config_path(base_dir, path))
    None => ()
  }
  match optional_config_string(object, "url") {
    Some(url) => return @lepusa.Source::url(url)
    None => ()
  }
  match optional_config_object(object, "localhost") {
    Some(localhost) => return localhost_source_from_object(localhost, problems)
    None => ()
  }
  problems.push(
    "project source must include html, localPath, packaged, url, or localhost",
  )
  @lepusa.Source::html("<main></main>")
}

///|
fn localhost_source_from_object(
  object : Map[String, Json],
  problems : Array[String],
) -> @lepusa.Source {
  let port = required_config_int(object, "port", problems)
  let host = optional_config_string(object, "host").unwrap_or("127.0.0.1")
  let path = optional_config_string(object, "path").unwrap_or("/")
  let readiness_path = optional_config_string(object, "readinessPath")
  let command = optional_config_string_array(object, "command", problems).unwrap_or([],
  )
  @lepusa.Source::localhost(port~, host~, path~, readiness_path?, command~)
}

///|
