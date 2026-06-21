///|
pub(all) enum LifecycleEvent {
  AppStarted
  AppWillExit
  PluginSetup(String)
  PluginReady(String)
  PluginWillExit(String)
  WindowCloseRequested(String)
  WindowClosed(String)
} derive(Debug, Eq)

///|
pub struct LifecycleHook {
  event : LifecycleEvent
  command : Cmd
} derive(Debug, Eq)

///|
pub fn LifecycleHook::new(
  event : LifecycleEvent,
  command : Cmd,
) -> LifecycleHook {
  { event, command }
}

///|
pub fn LifecycleHook::event(self : LifecycleHook) -> LifecycleEvent {
  self.event
}

///|
pub fn LifecycleHook::command(self : LifecycleHook) -> Cmd {
  self.command
}

///|
pub fn LifecycleEvent::app_started() -> LifecycleEvent {
  AppStarted
}

///|
pub fn LifecycleEvent::app_will_exit() -> LifecycleEvent {
  AppWillExit
}

///|
pub fn LifecycleEvent::plugin_setup(name : String) -> LifecycleEvent {
  PluginSetup(name)
}

///|
pub fn LifecycleEvent::plugin_ready(name : String) -> LifecycleEvent {
  PluginReady(name)
}

///|
pub fn LifecycleEvent::plugin_will_exit(name : String) -> LifecycleEvent {
  PluginWillExit(name)
}

///|
pub fn LifecycleEvent::window_close_requested(label : String) -> LifecycleEvent {
  WindowCloseRequested(label)
}

///|
pub fn LifecycleEvent::window_closed(label : String) -> LifecycleEvent {
  WindowClosed(label)
}

///|
fn LifecycleEvent::validate(
  self : LifecycleEvent,
  windows : Array[WindowConfig],
  plugins? : Array[Plugin] = [],
) -> Array[String] {
  let problems : Array[String] = []
  match self {
    AppStarted | AppWillExit => ()
    PluginSetup(name) | PluginReady(name) | PluginWillExit(name) =>
      validate_lifecycle_plugin(name, plugins, problems)
    WindowCloseRequested(label) =>
      validate_lifecycle_window(label, windows, problems)
    WindowClosed(label) => validate_lifecycle_window(label, windows, problems)
  }
  problems
}

///|
fn LifecycleEvent::plugin_name(self : LifecycleEvent) -> String? {
  match self {
    PluginSetup(name) | PluginReady(name) | PluginWillExit(name) => Some(name)
    _ => None
  }
}

///|
fn validate_lifecycle_window(
  label : String,
  windows : Array[WindowConfig],
  problems : Array[String],
) -> Unit {
  if label == "" {
    problems.push("lifecycle window label is required")
  } else if !windows.has_window_label(label) {
    problems.push("lifecycle window not found: \{label}")
  }
}

///|
fn validate_lifecycle_plugin(
  name : String,
  plugins : Array[Plugin],
  problems : Array[String],
) -> Unit {
  if name == "" {
    problems.push("lifecycle plugin name is required")
  } else if !plugins.has_plugin_name(name) {
    problems.push("lifecycle plugin not found: \{name}")
  }
}

///|
fn Array::has_window_label(self : Array[WindowConfig], label : String) -> Bool {
  for window in self {
    if window.label() == label {
      return true
    }
  }
  false
}

///|
fn Array::has_plugin_name(self : Array[Plugin], name : String) -> Bool {
  for plugin in self {
    if plugin.name() == name {
      return true
    }
  }
  false
}
