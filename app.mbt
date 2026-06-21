///|
pub struct LaunchPlan {
  root : Cell
  windows : Array[WindowConfig]
  plugins : Array[Plugin]
  capabilities : Array[Capability]
  startup : Cmd
  lifecycle_hooks : Array[LifecycleHook]
} derive(Debug, Eq)

///|
pub fn LaunchPlan::window_count(self : LaunchPlan) -> Int {
  self.windows.length()
}

///|
pub fn LaunchPlan::windows(self : LaunchPlan) -> Array[WindowConfig] {
  self.windows.copy()
}

///|
pub fn LaunchPlan::plugin_count(self : LaunchPlan) -> Int {
  self.plugins.length()
}

///|
pub fn LaunchPlan::plugins(self : LaunchPlan) -> Array[Plugin] {
  self.plugins.copy()
}

///|
pub fn LaunchPlan::capability_count(self : LaunchPlan) -> Int {
  self.capabilities.length()
}

///|
pub fn LaunchPlan::capabilities(self : LaunchPlan) -> Array[Capability] {
  self.capabilities.copy()
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
pub fn LaunchPlan::startup(self : LaunchPlan) -> Cmd {
  self.startup
}

///|
pub fn LaunchPlan::lifecycle_hooks(self : LaunchPlan) -> Array[LifecycleHook] {
  self.lifecycle_hooks.copy()
}

///|
pub struct App {
  root : Cell
  windows : Array[WindowConfig]
  plugins : Array[Plugin]
  capabilities : Array[Capability]
  startup : Cmd
  lifecycle_hooks : Array[LifecycleHook]
} derive(Debug, Eq)

///|
pub fn new(root : Cell) -> App {
  {
    root,
    windows: [],
    plugins: [],
    capabilities: [],
    startup: None,
    lifecycle_hooks: [],
  }
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
pub fn App::with_lifecycle(
  self : App,
  event : LifecycleEvent,
  command : Cmd,
) -> App {
  let lifecycle_hooks = self.lifecycle_hooks.copy()
  lifecycle_hooks.push(LifecycleHook::new(event, command))
  { ..self, lifecycle_hooks, }
}

///|
pub fn App::on_shutdown(self : App, command : Cmd) -> App {
  self.with_lifecycle(AppWillExit, command)
}

///|
pub fn App::on_window_close_requested(
  self : App,
  label : String,
  command : Cmd,
) -> App {
  self.with_lifecycle(WindowCloseRequested(label), command)
}

///|
pub fn App::on_window_closed(self : App, label : String, command : Cmd) -> App {
  self.with_lifecycle(WindowClosed(label), command)
}

///|
pub fn App::validate(self : App) -> Array[String] {
  let problems : Array[String] = []
  if self.windows.is_empty() {
    problems.push("at least one window is required")
  }
  let windows = self.materialized_windows()
  let labels : Array[String] = []
  for window in windows {
    for problem in window.validate_for_app() {
      problems.push(problem)
    }
    let label = window.label()
    if label != "" && labels.contains(label) {
      problems.push("window label must be unique: \{label}")
    } else {
      labels.push(label)
    }
  }
  for plugin in self.plugins {
    for problem in plugin.validate() {
      problems.push(problem)
    }
  }
  self.validate_plugin_routes(problems)
  for capability in self.capabilities {
    for problem in capability.validate() {
      problems.push(problem)
    }
  }
  for hook in self.materialized_lifecycle_hooks() {
    for problem in hook.event().validate(windows, plugins=self.plugins) {
      problems.push(problem)
    }
  }
  problems
}

///|
fn App::validate_plugin_routes(self : App, problems : Array[String]) -> Unit {
  let plugin_names : Array[String] = []
  let command_routes : Array[String] = []
  for plugin in self.plugins {
    let name = plugin.name()
    if name != "" && plugin_names.contains(name) {
      problems.push("plugin name must be unique: \{name}")
    } else {
      plugin_names.push(name)
    }
    for route in plugin.command_routes() {
      if route != "." && command_routes.contains(route) {
        problems.push("plugin command route must be unique: \{route}")
      } else {
        command_routes.push(route)
      }
    }
  }
}

///|
pub fn App::launch_plan(self : App) -> Result[LaunchPlan, Array[String]] {
  let problems = self.validate()
  if problems.is_empty() {
    Ok({
      root: self.root,
      windows: self.materialized_windows(),
      plugins: self.plugins.copy(),
      capabilities: self.capabilities.copy(),
      startup: self.startup,
      lifecycle_hooks: self.materialized_lifecycle_hooks(),
    })
  } else {
    Err(problems)
  }
}

///|
fn App::materialized_windows(self : App) -> Array[WindowConfig] {
  let windows : Array[WindowConfig] = []
  for window in self.windows {
    windows.push(window.with_default_source(self.root))
  }
  windows
}

///|
fn App::materialized_lifecycle_hooks(self : App) -> Array[LifecycleHook] {
  let hooks = self.lifecycle_hooks.copy()
  for plugin in self.plugins {
    for hook in plugin.lifecycle_hooks() {
      hooks.push(hook)
    }
  }
  hooks
}
