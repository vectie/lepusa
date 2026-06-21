///|
pub(all) enum RuntimeAction {
  RuntimeEffect(String)
  RuntimeEmit(EventTarget, Event)
  RuntimeNavigate(String, ResolvedSource)
} derive(Debug, Eq)

///|
pub struct RuntimeLifecycleHook {
  event : LifecycleEvent
  actions : Array[RuntimeAction]
} derive(Debug, Eq)

///|
pub fn RuntimePlan::startup_actions(
  self : RuntimePlan,
) -> Result[Array[RuntimeAction], Array[String]] {
  self.lifecycle_actions(AppStarted)
}

///|
pub fn RuntimePlan::lifecycle_actions(
  self : RuntimePlan,
  event : LifecycleEvent,
) -> Result[Array[RuntimeAction], Array[String]] {
  let actions : Array[RuntimeAction] = []
  let problems : Array[String] = []
  if event is AppStarted {
    self.collect_actions(self.launch.startup(), actions, problems)
  }
  for hook in self.launch.lifecycle_hooks() {
    if hook.event() == event {
      self.collect_actions(hook.command(), actions, problems)
    }
  }
  if problems.is_empty() {
    Ok(actions)
  } else {
    Err(problems)
  }
}

///|
pub fn RuntimePlan::lifecycle_hooks(
  self : RuntimePlan,
) -> Result[Array[RuntimeLifecycleHook], Array[String]] {
  let events : Array[LifecycleEvent] = []
  if !self.launch.startup().is_empty() {
    events.push(AppStarted)
  }
  for hook in self.launch.lifecycle_hooks() {
    let event = hook.event()
    if !events.contains(event) {
      events.push(event)
    }
  }
  let hooks : Array[RuntimeLifecycleHook] = []
  let problems : Array[String] = []
  for event in events {
    match self.lifecycle_actions(event) {
      Ok(actions) =>
        if !actions.is_empty() {
          hooks.push(RuntimeLifecycleHook::new(event, actions))
        }
      Err(action_problems) =>
        for problem in action_problems {
          problems.push(problem)
        }
    }
  }
  if problems.is_empty() {
    Ok(hooks)
  } else {
    Err(problems)
  }
}

///|
pub fn RuntimePlan::actions(
  self : RuntimePlan,
  command : Cmd,
) -> Result[Array[RuntimeAction], Array[String]] {
  let actions : Array[RuntimeAction] = []
  let problems : Array[String] = []
  self.collect_actions(command, actions, problems)
  if problems.is_empty() {
    Ok(actions)
  } else {
    Err(problems)
  }
}

///|
fn RuntimePlan::collect_actions(
  self : RuntimePlan,
  command : Cmd,
  actions : Array[RuntimeAction],
  problems : Array[String],
) -> Unit {
  match command {
    None => ()
    Batch(commands) =>
      for command in commands {
        self.collect_actions(command, actions, problems)
      }
    Effect(name) =>
      if name == "" {
        problems.push("effect name is required")
      } else {
        actions.push(RuntimeEffect(name))
      }
    Emit(target, event) => {
      let event_problems = event.validate()
      for problem in event_problems {
        problems.push(problem)
      }
      if event_problems.is_empty() {
        actions.push(RuntimeEmit(target, event))
      }
    }
    Navigate(window_label, source) =>
      if window_label == "" {
        problems.push("navigate window label is required")
      } else if !self.has_window(window_label) {
        problems.push("navigate window not found: \{window_label}")
      } else {
        match
          source.resolve(window_label~, asset_protocol=self.asset_protocol) {
          Ok(resolved) => actions.push(RuntimeNavigate(window_label, resolved))
          Err(problem) => problems.push(problem)
        }
      }
  }
}

///|
fn RuntimePlan::has_window(self : RuntimePlan, label : String) -> Bool {
  for window in self.windows {
    if window.label() == label {
      return true
    }
  }
  false
}

///|
pub fn RuntimeLifecycleHook::new(
  event : LifecycleEvent,
  actions : Array[RuntimeAction],
) -> RuntimeLifecycleHook {
  { event, actions }
}

///|
pub fn RuntimeLifecycleHook::event(
  self : RuntimeLifecycleHook,
) -> LifecycleEvent {
  self.event
}

///|
pub fn RuntimeLifecycleHook::actions(
  self : RuntimeLifecycleHook,
) -> Array[RuntimeAction] {
  self.actions.copy()
}

///|
pub fn RuntimeLifecycleHook::to_json(self : RuntimeLifecycleHook) -> String {
  [
    "{",
    "\"event\":\{self.event.to_json()},",
    "\"actions\":[\{self.actions.map(fn(action) { action.to_json() }).join(",")}]",
    "}",
  ].join("")
}

///|
pub fn RuntimeAction::to_json(self : RuntimeAction) -> String {
  match self {
    RuntimeEffect(name) =>
      ["{", "\"kind\":\"effect\",", "\"name\":\{name.json_string()}", "}"].join(
        "",
      )
    RuntimeEmit(target, event) =>
      [
        "{",
        "\"kind\":\"emit\",",
        "\"target\":\{target.to_json()},",
        "\"event\":\{event.to_json()}",
        "}",
      ].join("")
    RuntimeNavigate(window_label, source) =>
      [
        "{",
        "\"kind\":\"navigate\",",
        "\"windowLabel\":\{window_label.json_string()},",
        "\"url\":\{source.url().json_string()},",
        "\"protocolMappings\":[\{source.protocol_mappings().map(protocol_mapping_json).join(",")}],",
        "\"virtualFiles\":[\{source.virtual_files().map(virtual_file_json).join(",")}]",
        "}",
      ].join("")
  }
}

///|
pub fn LifecycleEvent::to_json(self : LifecycleEvent) -> String {
  match self {
    AppStarted => "{\"kind\":\"app-started\"}"
    AppWillExit => "{\"kind\":\"app-will-exit\"}"
    PluginSetup(name) => plugin_lifecycle_event_json("plugin-setup", name)
    PluginReady(name) => plugin_lifecycle_event_json("plugin-ready", name)
    PluginWillExit(name) =>
      plugin_lifecycle_event_json("plugin-will-exit", name)
    WindowCloseRequested(label) =>
      [
        "{",
        "\"kind\":\"window-close-requested\",",
        "\"label\":\{label.json_string()}",
        "}",
      ].join("")
    WindowClosed(label) =>
      [
        "{",
        "\"kind\":\"window-closed\",",
        "\"label\":\{label.json_string()}",
        "}",
      ].join("")
  }
}

///|
fn plugin_lifecycle_event_json(kind : String, name : String) -> String {
  [
    "{",
    "\"kind\":\{kind.json_string()},",
    "\"plugin\":\{name.json_string()}",
    "}",
  ].join("")
}

///|
pub fn EventTarget::to_json(self : EventTarget) -> String {
  match self {
    AppTarget => "{\"kind\":\"app\"}"
    WindowTarget(label) =>
      ["{", "\"kind\":\"window\",", "\"label\":\{label.json_string()}", "}"].join(
        "",
      )
    WebviewTarget(label) =>
      ["{", "\"kind\":\"webview\",", "\"label\":\{label.json_string()}", "}"].join(
        "",
      )
  }
}

///|
fn protocol_mapping_json(mapping : ProtocolMapping) -> String {
  [
    "{",
    "\"scheme\":\{mapping.scheme().json_string()},",
    "\"root\":\{mapping.root().json_string()}",
    "}",
  ].join("")
}

///|
fn virtual_file_json(file : VirtualFile) -> String {
  [
    "{",
    "\"path\":\{file.path().json_string()},",
    "\"mimeType\":\{mime_type_for_path(file.path()).json_string()},",
    "\"content\":\{file.content().json_string()}",
    "}",
  ].join("")
}
