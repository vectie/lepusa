///|
pub(all) enum LifecycleEvent {
  AppStarted
  AppWillExit
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
) -> Array[String] {
  let problems : Array[String] = []
  match self {
    AppStarted | AppWillExit => ()
    WindowCloseRequested(label) =>
      validate_lifecycle_window(label, windows, problems)
    WindowClosed(label) => validate_lifecycle_window(label, windows, problems)
  }
  problems
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
fn Array::has_window_label(self : Array[WindowConfig], label : String) -> Bool {
  for window in self {
    if window.label() == label {
      return true
    }
  }
  false
}
