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
} derive(Debug, Eq)

///|
pub fn RuntimeConfig::system_webview(
  devtools? : Bool = false,
  asset_protocol? : String = "lepusa",
) -> RuntimeConfig {
  { backend: SystemWebView, devtools, asset_protocol }
}

///|
pub fn RuntimeConfig::headless() -> RuntimeConfig {
  { backend: Headless, devtools: false, asset_protocol: "lepusa" }
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
pub struct RuntimePlan {
  launch : LaunchPlan
  backend : RuntimeBackend
  devtools : Bool
  asset_protocol : String
  command_routes : Array[String]
  windows : Array[ResolvedWindow]
  filesystem_scopes : Array[FileSystemScope]
} derive(Debug, Eq)

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
pub fn RuntimePlan::command_routes(self : RuntimePlan) -> Array[String] {
  self.command_routes.copy()
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
  let routes : Array[String] = []
  for plugin in self.launch.plugins() {
    for command in plugin.commands() {
      let route = "\{plugin.name()}.\{command.name()}"
      if self
        .capabilities()
        .allow_invoke(window_label~, permission=command.permission()) {
        routes.push(route)
      }
    }
  }
  routes
}

///|
pub fn RuntimePlan::capabilities(self : RuntimePlan) -> Array[Capability] {
  self.launch.capabilities()
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
          launch,
          backend: config.backend,
          devtools: config.devtools,
          asset_protocol: config.asset_protocol,
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
