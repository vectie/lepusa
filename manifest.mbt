///|
pub struct ProjectManifest {
  metadata : AppMetadata
  windows : Array[WindowConfig]
  plugins : Array[Plugin]
  capabilities : Array[Capability]
  startup : Cmd
  lifecycle_hooks : Array[LifecycleHook]
  runtime : RuntimeConfig
} derive(Debug, Eq)

///|
pub fn ProjectManifest::new(
  metadata : AppMetadata,
  windows? : Array[WindowConfig] = [],
  plugins? : Array[Plugin] = [],
  capabilities? : Array[Capability] = [],
  startup? : Cmd = None,
  lifecycle_hooks? : Array[LifecycleHook] = [],
  runtime? : RuntimeConfig = RuntimeConfig::system_webview(),
) -> ProjectManifest {
  {
    metadata,
    windows,
    plugins,
    capabilities,
    startup,
    lifecycle_hooks,
    runtime,
  }
}

///|
pub fn ProjectManifest::metadata(self : ProjectManifest) -> AppMetadata {
  self.metadata
}

///|
pub fn ProjectManifest::windows(self : ProjectManifest) -> Array[WindowConfig] {
  self.windows.copy()
}

///|
pub fn ProjectManifest::plugins(self : ProjectManifest) -> Array[Plugin] {
  self.plugins.copy()
}

///|
pub fn ProjectManifest::capabilities(
  self : ProjectManifest,
) -> Array[Capability] {
  self.capabilities.copy()
}

///|
pub fn ProjectManifest::runtime(self : ProjectManifest) -> RuntimeConfig {
  self.runtime
}

///|
pub fn ProjectManifest::lifecycle_hooks(
  self : ProjectManifest,
) -> Array[LifecycleHook] {
  self.lifecycle_hooks.copy()
}

///|
pub fn ProjectManifest::with_window(
  self : ProjectManifest,
  window : WindowConfig,
) -> ProjectManifest {
  let windows = self.windows.copy()
  windows.push(window)
  { ..self, windows, }
}

///|
pub fn ProjectManifest::with_plugin(
  self : ProjectManifest,
  plugin : Plugin,
) -> ProjectManifest {
  let plugins = self.plugins.copy()
  plugins.push(plugin)
  { ..self, plugins, }
}

///|
pub fn ProjectManifest::with_capability(
  self : ProjectManifest,
  capability : Capability,
) -> ProjectManifest {
  let capabilities = self.capabilities.copy()
  capabilities.push(capability)
  { ..self, capabilities, }
}

///|
pub fn ProjectManifest::with_startup(
  self : ProjectManifest,
  startup : Cmd,
) -> ProjectManifest {
  { ..self, startup, }
}

///|
pub fn ProjectManifest::with_lifecycle(
  self : ProjectManifest,
  event : LifecycleEvent,
  command : Cmd,
) -> ProjectManifest {
  let lifecycle_hooks = self.lifecycle_hooks.copy()
  lifecycle_hooks.push(LifecycleHook::new(event, command))
  { ..self, lifecycle_hooks, }
}

///|
pub fn ProjectManifest::with_runtime(
  self : ProjectManifest,
  runtime : RuntimeConfig,
) -> ProjectManifest {
  { ..self, runtime, }
}

///|
pub fn ProjectManifest::validate(self : ProjectManifest) -> Array[String] {
  let problems = self.metadata.validate()
  for problem in self.runtime.validate() {
    problems.push(problem)
  }
  if self.windows.is_empty() {
    problems.push("at least one window is required")
  }
  let labels : Array[String] = []
  for window in self.windows {
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
  for capability in self.capabilities {
    for problem in capability.validate() {
      problems.push(problem)
    }
  }
  for hook in self.lifecycle_hooks {
    for problem in hook.event().validate(self.windows) {
      problems.push(problem)
    }
  }
  problems
}

///|
pub fn ProjectManifest::app(self : ProjectManifest, root : Cell) -> App {
  let mut app = new(root).with_startup(self.startup)
  for window in self.windows {
    app = app.with_window(window)
  }
  for plugin in self.plugins {
    app = app.with_plugin(plugin)
  }
  for capability in self.capabilities {
    app = app.with_capability(capability)
  }
  for hook in self.lifecycle_hooks {
    app = app.with_lifecycle(hook.event(), hook.command())
  }
  app
}

///|
pub fn ProjectManifest::launch_plan(
  self : ProjectManifest,
  root : Cell,
) -> Result[LaunchPlan, Array[String]] {
  let problems = self.validate()
  if problems.is_empty() {
    self.app(root).launch_plan()
  } else {
    Err(problems)
  }
}

///|
pub fn ProjectManifest::runtime_plan(
  self : ProjectManifest,
  root : Cell,
) -> Result[RuntimePlan, Array[String]] {
  let problems = self.validate()
  if problems.is_empty() {
    self.app(root).runtime_plan(config=self.runtime)
  } else {
    Err(problems)
  }
}

///|
pub fn ProjectManifest::bundle_plan(
  self : ProjectManifest,
  root : Cell,
  target? : BundleTarget = MacOS,
  registered_routes? : Array[String] = [],
) -> Result[BundlePlan, Array[String]] {
  match self.runtime_plan(root) {
    Ok(runtime) =>
      BundleConfig::new(self.metadata, target~).plan(
        runtime,
        registered_routes~,
      )
    Err(problems) => Err(problems)
  }
}
