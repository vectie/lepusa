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
  self.launch.window_count()
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
pub fn App::runtime_plan(
  self : App,
  config? : RuntimeConfig = RuntimeConfig::system_webview(),
) -> Result[RuntimePlan, Array[String]] {
  let problems = config.validate()
  match self.launch_plan() {
    Ok(launch) =>
      if problems.is_empty() {
        Ok({
          launch,
          backend: config.backend,
          devtools: config.devtools,
          asset_protocol: config.asset_protocol,
          command_routes: launch.command_routes(),
        })
      } else {
        Err(problems)
      }
    Err(app_problems) => {
      for problem in app_problems {
        problems.push(problem)
      }
      Err(problems)
    }
  }
}
