///|
pub(all) enum RuntimeBackend {
  SystemWebView
  Headless
} derive(Debug, Eq)

///|
pub struct RuntimeConfig {
  backend : RuntimeBackend
  devtools : Bool
  asset_protocol : String
  platform : String
} derive(Debug, Eq)

///|
pub fn RuntimeConfig::system_webview(
  devtools? : Bool = false,
  asset_protocol? : String = "lepusa",
  platform? : String = "",
) -> RuntimeConfig {
  { backend: SystemWebView, devtools, asset_protocol, platform }
}

///|
pub fn RuntimeConfig::headless(platform? : String = "") -> RuntimeConfig {
  { backend: Headless, devtools: false, asset_protocol: "lepusa", platform }
}

///|
pub fn RuntimeConfig::validate(self : RuntimeConfig) -> Array[String] {
  let problems : Array[String] = []
  if self.asset_protocol == "" {
    problems.push("runtime asset protocol is required")
  }
  problems
}

///|
pub fn RuntimeConfig::platform(self : RuntimeConfig) -> String {
  self.platform
}

///|
pub struct RuntimePlan {
  app_metadata : AppMetadata?
  launch : LaunchPlan
  backend : RuntimeBackend
  devtools : Bool
  asset_protocol : String
  platform : String
  command_routes : Array[String]
  windows : Array[ResolvedWindow]
  filesystem_scopes : Array[FileSystemScope]
} derive(Debug, Eq)

///|
pub fn RuntimePlan::app_metadata(self : RuntimePlan) -> AppMetadata? {
  self.app_metadata
}

///|
pub fn RuntimePlan::backend(self : RuntimePlan) -> RuntimeBackend {
  self.backend
}

///|
pub fn RuntimeBackend::name(self : RuntimeBackend) -> String {
  match self {
    SystemWebView => "system-webview"
    Headless => "headless"
  }
}

///|
pub fn RuntimePlan::asset_protocol(self : RuntimePlan) -> String {
  self.asset_protocol
}

///|
pub fn RuntimePlan::platform(self : RuntimePlan) -> String {
  self.platform
}

///|
pub fn RuntimePlan::devtools(self : RuntimePlan) -> Bool {
  self.devtools
}

///|
pub fn RuntimePlan::window_count(self : RuntimePlan) -> Int {
  self.windows.length()
}

///|
pub fn RuntimePlan::windows(self : RuntimePlan) -> Array[ResolvedWindow] {
  self.windows.copy()
}

///|
pub fn RuntimePlan::plugin_count(self : RuntimePlan) -> Int {
  self.launch.plugin_count()
}

///|
pub fn RuntimePlan::capability_count(self : RuntimePlan) -> Int {
  self.launch.capability_count()
}

///|
pub fn RuntimePlan::capabilities(self : RuntimePlan) -> Array[Capability] {
  self.launch.capabilities()
}

///|
pub fn RuntimePlan::command_routes(self : RuntimePlan) -> Array[String] {
  self.command_routes.copy()
}

///|
pub fn RuntimePlan::command_manifest(self : RuntimePlan) -> CommandManifest {
  CommandManifest::from_plugins(
    plugins=self.launch.plugins(),
    capabilities=self.capabilities(),
    windows=self.windows(),
    platform=self.platform(),
  )
}

///|
pub fn RuntimePlan::permission_manifest(
  self : RuntimePlan,
) -> PermissionManifest {
  PermissionManifest::from_command_manifest(
    self.command_manifest(),
    capabilities=self.capabilities(),
  )
}

///|
pub fn RuntimePlan::command_routes_by_mode(
  self : RuntimePlan,
  mode : CommandMode,
) -> Array[String] {
  self.command_manifest().routes_by_mode(mode)
}

///|
pub fn RuntimePlan::file_system_scopes(
  self : RuntimePlan,
) -> Array[FileSystemScope] {
  self.filesystem_scopes.copy()
}

///|
fn RuntimePlan::with_file_system_scopes(
  self : RuntimePlan,
  scopes : Array[FileSystemScope],
) -> RuntimePlan {
  { ..self, filesystem_scopes: scopes.copy() }
}

///|
fn RuntimePlan::with_app_metadata(
  self : RuntimePlan,
  metadata : AppMetadata,
) -> RuntimePlan {
  { ..self, app_metadata: Some(metadata) }
}

///|
pub fn RuntimePlan::command_permission(
  self : RuntimePlan,
  route : String,
) -> Permission? {
  for plugin in self.launch.plugins() {
    for command in plugin.commands() {
      if "\{plugin.name()}.\{command.name()}" == route {
        return Some(command.permission())
      }
    }
  }
  None
}

///|
pub fn RuntimePlan::window_command_routes(
  self : RuntimePlan,
  window_label : String,
) -> Array[String] {
  self.command_manifest().allowed_routes(window_label)
}

///|
pub fn App::runtime_plan(
  self : App,
  config? : RuntimeConfig = RuntimeConfig::system_webview(),
) -> Result[RuntimePlan, Array[String]] {
  let problems = config.validate()
  match self.launch_plan() {
    Ok(launch) => {
      let windows : Array[ResolvedWindow] = []
      for window in launch.windows() {
        match window.resolve(asset_protocol=config.asset_protocol) {
          Ok(resolved) => windows.push(resolved)
          Err(window_problems) =>
            for problem in window_problems {
              problems.push(problem)
            }
        }
      }
      if problems.is_empty() {
        Ok({
          app_metadata: None,
          launch,
          backend: config.backend,
          devtools: config.devtools,
          asset_protocol: config.asset_protocol,
          platform: config.platform,
          command_routes: launch.command_routes(),
          windows,
          filesystem_scopes: [],
        })
      } else {
        Err(problems)
      }
    }
    Err(app_problems) => {
      for problem in app_problems {
        problems.push(problem)
      }
      Err(problems)
    }
  }
}
