///|
pub struct LaunchPlan {
  root : Cell
  windows : Array[WindowConfig]
  plugins : Array[Plugin]
  capabilities : Array[Capability]
  startup : Cmd
} derive(Debug, Eq)

///|
pub fn LaunchPlan::window_count(self : LaunchPlan) -> Int {
  self.windows.length()
}

///|
pub fn LaunchPlan::plugin_count(self : LaunchPlan) -> Int {
  self.plugins.length()
}

///|
pub fn LaunchPlan::capability_count(self : LaunchPlan) -> Int {
  self.capabilities.length()
}

///|
pub fn LaunchPlan::command_routes(self : LaunchPlan) -> Array[String] {
  let routes : Array[String] = []
  for plugin in self.plugins {
    for route in plugin.command_routes() {
      routes.push(route)
    }
  }
  routes
}

///|
pub struct App {
  root : Cell
  windows : Array[WindowConfig]
  plugins : Array[Plugin]
  capabilities : Array[Capability]
  startup : Cmd
} derive(Debug, Eq)

///|
pub fn new(root : Cell) -> App {
  { root, windows: [], plugins: [], capabilities: [], startup: Cmd::None }
}

///|
pub fn App::with_window(self : App, window : WindowConfig) -> App {
  let windows = self.windows.copy()
  windows.push(window)
  { ..self, windows, }
}

///|
pub fn App::window(
  self : App,
  label? : String = "main",
  title? : String = "Lepusa",
  width? : Int = 1000,
  height? : Int = 720,
  resizable? : Bool = true,
  title_bar? : TitleBarStyle = Native,
  source? : Source,
) -> App {
  self.with_window(
    WindowConfig::new(
      label~,
      title~,
      width~,
      height~,
      resizable~,
      title_bar~,
      source?,
    ),
  )
}

///|
pub fn App::with_plugin(self : App, plugin : Plugin) -> App {
  let plugins = self.plugins.copy()
  plugins.push(plugin)
  { ..self, plugins, }
}

///|
pub fn App::with_capability(self : App, capability : Capability) -> App {
  let capabilities = self.capabilities.copy()
  capabilities.push(capability)
  { ..self, capabilities, }
}

///|
pub fn App::with_startup(self : App, startup : Cmd) -> App {
  { ..self, startup, }
}

///|
pub fn App::validate(self : App) -> Array[String] {
  let problems : Array[String] = []
  if self.windows.is_empty() {
    problems.push("at least one window is required")
  }
  for window in self.windows {
    for problem in window.validate() {
      problems.push(problem)
    }
  }
  for plugin in self.plugins {
    for problem in plugin.validate() {
      problems.push(problem)
    }
  }
  for capability in self.capabilities {
    for problem in capability.validate() {
      problems.push(problem)
    }
  }
  problems
}

///|
pub fn App::launch_plan(self : App) -> Result[LaunchPlan, Array[String]] {
  let problems = self.validate()
  if problems.is_empty() {
    Ok({
      root: self.root,
      windows: self.windows.copy(),
      plugins: self.plugins.copy(),
      capabilities: self.capabilities.copy(),
      startup: self.startup,
    })
  } else {
    Err(problems)
  }
}
