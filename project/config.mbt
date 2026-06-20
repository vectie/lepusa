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
  let runtime_dependency_sources = project_runtime_dependency_sources_from_object(
    object,
    base_dir~,
    problems,
  )
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
      runtime_dependency_sources~,
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
    let registry = project_registry_from_plugins(
      plugins,
      filesystem_scopes~,
      local_services=project_local_services(manifest, root),
    )
    Ok({ manifest, root, registry })
  } else {
    Err(problems)
  }
}

///|
fn project_local_services(
  manifest : @lepusa.ProjectManifest,
  root : @lepusa.Cell,
) -> Array[@lepusa.LocalService] {
  match manifest.runtime_plan(root) {
    Ok(plan) =>
      match plan.launch_manifest() {
        Ok(launch) => launch.local_services()
        Err(_) => []
      }
    Err(_) => []
  }
}

///|
