///|
pub(all) enum RuntimeOperation {
  RuntimeStartService(@lepusa.LocalService)
  RuntimeSendEvent(@lepusa.EventTarget, @lepusa.Event)
  RuntimeRunEffect(String)
  RuntimeNavigateWindow(String, String)
} derive(Debug, Eq)

///|
pub struct RuntimeStep {
  session : RuntimeSession
  operations : Array[RuntimeOperation]
} derive(Debug, Eq)

///|
pub fn RuntimeStep::session(self : RuntimeStep) -> RuntimeSession {
  self.session
}

///|
pub fn RuntimeStep::operations(self : RuntimeStep) -> Array[RuntimeOperation] {
  self.operations.copy()
}

///|
pub fn RuntimeOperation::to_json(self : RuntimeOperation) -> String {
  match self {
    RuntimeStartService(service) =>
      [
        "{",
        "\"kind\":\"start-service\",",
        "\"service\":\{service.to_json()}",
        "}",
      ].join("")
    RuntimeSendEvent(target, event) =>
      [
        "{",
        "\"kind\":\"send-event\",",
        "\"target\":\{target.to_json()},",
        "\"event\":\{event.to_json()}",
        "}",
      ].join("")
    RuntimeRunEffect(name) =>
      ["{", "\"kind\":\"run-effect\",", "\"name\":\{name.json_string()}", "}"].join(
        "",
      )
    RuntimeNavigateWindow(label, url) =>
      [
        "{",
        "\"kind\":\"navigate-window\",",
        "\"label\":\{label.json_string()},",
        "\"url\":\{url.json_string()}",
        "}",
      ].join("")
  }
}

///|
pub fn RuntimeHost::startup_step(
  self : RuntimeHost,
) -> Result[RuntimeStep, Array[String]] {
  match self.snapshot() {
    Ok(session) => session.apply_actions(session.startup_actions())
    Err(problems) => Err(problems)
  }
}

///|
pub fn RuntimeHost::lifecycle_step(
  self : RuntimeHost,
  session : RuntimeSession,
  event : @lepusa.LifecycleEvent,
) -> Result[RuntimeStep, Array[String]] {
  ignore(self)
  session.lifecycle_step(event)
}

///|
pub fn RuntimeSession::lifecycle_actions(
  self : RuntimeSession,
  event : @lepusa.LifecycleEvent,
) -> Array[@lepusa.RuntimeAction] {
  let actions : Array[@lepusa.RuntimeAction] = []
  for hook in self.lifecycle_hooks {
    if hook.event() == event {
      for action in hook.actions() {
        actions.push(action)
      }
    }
  }
  actions
}

///|
pub fn RuntimeSession::lifecycle_step(
  self : RuntimeSession,
  event : @lepusa.LifecycleEvent,
) -> Result[RuntimeStep, Array[String]] {
  self.apply_actions(self.lifecycle_actions(event))
}

///|
pub fn RuntimeSession::apply_actions(
  self : RuntimeSession,
  actions : Array[@lepusa.RuntimeAction],
) -> Result[RuntimeStep, Array[String]] {
  let mut session = self
  let operations : Array[RuntimeOperation] = []
  let problems : Array[String] = []
  for action in actions {
    match session.apply_action(action, operations) {
      Ok(next) => session = next
      Err(problem) => problems.push(problem)
    }
  }
  if problems.is_empty() {
    Ok({ session, operations })
  } else {
    Err(problems)
  }
}

///|
fn RuntimeSession::apply_action(
  self : RuntimeSession,
  action : @lepusa.RuntimeAction,
  operations : Array[RuntimeOperation],
) -> Result[RuntimeSession, String] {
  match action {
    RuntimeEffect(name) =>
      if name == "" {
        Err("effect name is required")
      } else {
        operations.push(RuntimeRunEffect(name))
        Ok(self)
      }
    RuntimeEmit(target, event) =>
      if event.name() == "" {
        Err("event name is required")
      } else {
        operations.push(RuntimeSendEvent(target, event))
        Ok(self)
      }
    RuntimeNavigate(window_label, source) =>
      self.navigate_window(window_label, source, operations)
  }
}

///|
fn RuntimeSession::navigate_window(
  self : RuntimeSession,
  window_label : String,
  source : @lepusa.ResolvedSource,
  operations : Array[RuntimeOperation],
) -> Result[RuntimeSession, String] {
  if window_label == "" {
    return Err("navigate window label is required")
  }
  let windows : Array[RuntimeWindow] = []
  let mut found = false
  for window in self.windows {
    if window.label() == window_label {
      found = true
      windows.push({ ..window, url: source.url() })
    } else {
      windows.push(window)
    }
  }
  if !found {
    return Err("navigate window not found: \{window_label}")
  }
  let protocol_mappings = self.protocol_mappings_without(window_label)
  for mapping in source.protocol_mappings() {
    protocol_mappings.push(
      RuntimeProtocolMapping::from_mapping(window_label, mapping),
    )
  }
  let virtual_files = self.virtual_files_without(window_label)
  for file in source.virtual_files() {
    virtual_files.push(RuntimeVirtualFile::from_file(window_label, file))
  }
  let local_services = self.local_services_without(window_label)
  for service in source.local_services() {
    local_services.push(service)
  }
  operations.push(RuntimeNavigateWindow(window_label, source.url()))
  Ok({ ..self, windows, protocol_mappings, virtual_files, local_services })
}

///|
fn RuntimeSession::protocol_mappings_without(
  self : RuntimeSession,
  window_label : String,
) -> Array[RuntimeProtocolMapping] {
  let mappings : Array[RuntimeProtocolMapping] = []
  for mapping in self.protocol_mappings {
    if mapping.window_label() != window_label {
      mappings.push(mapping)
    }
  }
  mappings
}

///|
fn RuntimeSession::virtual_files_without(
  self : RuntimeSession,
  window_label : String,
) -> Array[RuntimeVirtualFile] {
  let files : Array[RuntimeVirtualFile] = []
  for file in self.virtual_files {
    if file.window_label() != window_label {
      files.push(file)
    }
  }
  files
}

///|
fn RuntimeSession::local_services_without(
  self : RuntimeSession,
  window_label : String,
) -> Array[@lepusa.LocalService] {
  let services : Array[@lepusa.LocalService] = []
  for service in self.local_services {
    if service.name() != window_label {
      services.push(service)
    }
  }
  services
}
