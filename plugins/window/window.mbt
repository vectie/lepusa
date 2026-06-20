///|
pub(all) enum WindowControlAction {
  Close
  Focus
  Hide
  Maximize
  Minimize
  SetFullscreen
  SetPosition
  SetSize
  SetTitle
  Show
  Unmaximize
} derive(Debug, Eq)

///|
pub struct WindowControlOperation {
  window_label : String
  action : WindowControlAction
  payload : String
} derive(Debug, Eq)

///|
pub struct WindowControlPolicy {
  allowed_windows : Array[String]
} derive(Debug, Eq)

///|
pub struct WindowControlState {
  operations : Array[WindowControlOperation]
}

///|
pub fn WindowControlPolicy::new(
  allowed_windows? : Array[String] = [],
) -> WindowControlPolicy {
  { allowed_windows: allowed_windows.copy() }
}

///|
pub fn WindowControlPolicy::allowed_windows(
  self : WindowControlPolicy,
) -> Array[String] {
  self.allowed_windows.copy()
}

///|
pub fn WindowControlPolicy::window(
  self : WindowControlPolicy,
  label : String,
) -> WindowControlPolicy {
  let allowed_windows = self.allowed_windows.copy()
  allowed_windows.push(label)
  { allowed_windows, }
}

///|
pub fn WindowControlPolicy::validate(
  self : WindowControlPolicy,
) -> Array[String] {
  let problems : Array[String] = []
  let seen : Array[String] = []
  for label in self.allowed_windows {
    if label == "" {
      problems.push("window control allowed window label is required")
    } else if invalid_window_label(label) {
      problems.push("window control allowed window label is invalid: \{label}")
    } else if seen.contains(label) {
      problems.push("window control allowed window must be unique: \{label}")
    } else {
      seen.push(label)
    }
  }
  problems
}

///|
pub fn WindowControlPolicy::allows(
  self : WindowControlPolicy,
  window_label : String,
) -> Bool {
  self.allowed_windows.is_empty() || self.allowed_windows.contains(window_label)
}

///|
pub fn WindowControlState::new() -> WindowControlState {
  { operations: [] }
}

///|
pub fn WindowControlState::record(
  self : WindowControlState,
  operation : WindowControlOperation,
) -> Unit {
  self.operations.push(operation)
}

///|
pub fn WindowControlState::operations(
  self : WindowControlState,
) -> Array[WindowControlOperation] {
  self.operations.copy()
}

///|
pub fn WindowControlState::last(
  self : WindowControlState,
) -> WindowControlOperation? {
  self.operations.last()
}

///|
pub fn WindowControlOperation::new(
  window_label~ : String,
  action~ : WindowControlAction,
  payload? : String = "",
) -> WindowControlOperation {
  { window_label, action, payload }
}

///|
pub fn WindowControlOperation::window_label(
  self : WindowControlOperation,
) -> String {
  self.window_label
}

///|
pub fn WindowControlOperation::action(
  self : WindowControlOperation,
) -> WindowControlAction {
  self.action
}

///|
pub fn WindowControlOperation::payload(self : WindowControlOperation) -> String {
  self.payload
}

///|
pub fn WindowControlOperation::to_json(self : WindowControlOperation) -> String {
  self.to_json_value().stringify()
}

///|
pub fn WindowControlAction::name(self : WindowControlAction) -> String {
  match self {
    Close => "close"
    Focus => "focus"
    Hide => "hide"
    Maximize => "maximize"
    Minimize => "minimize"
    SetFullscreen => "setFullscreen"
    SetPosition => "setPosition"
    SetSize => "setSize"
    SetTitle => "setTitle"
    Show => "show"
    Unmaximize => "unmaximize"
  }
}

///|
pub fn plugin() -> @lepusa.Plugin {
  @lepusa.Plugin::new("window")
  .command_sync("close", permission=Window)
  .command_sync("focus", permission=Window)
  .command_sync("hide", permission=Window)
  .command_sync("maximize", permission=Window)
  .command_sync("minimize", permission=Window)
  .command_sync("setFullscreen", permission=Window)
  .command_sync("setPosition", permission=Window)
  .command_sync("setSize", permission=Window)
  .command_sync("setTitle", permission=Window)
  .command_sync("show", permission=Window)
  .command_sync("unmaximize", permission=Window)
  .command_event("onCloseRequested", permission=Window)
  .command_event("onFocusChanged", permission=Window)
  .command_event("onResized", permission=Window)
}

///|
pub fn capability(name? : String = "window") -> @lepusa.Capability {
  @lepusa.Capability::new(name).permission(Window)
}

///|
pub fn capability_for_window(
  window_label : String,
  name? : String = "window",
) -> @lepusa.Capability {
  capability(name~).window(window_label)
}

///|
pub fn registry(
  policy? : WindowControlPolicy = WindowControlPolicy::new(),
  state? : WindowControlState = WindowControlState::new(),
) -> @lepusa.CommandRegistry {
  register(@lepusa.CommandRegistry::new(), policy~, state~)
}

///|
pub fn register(
  registry : @lepusa.CommandRegistry,
  policy? : WindowControlPolicy = WindowControlPolicy::new(),
  state? : WindowControlState = WindowControlState::new(),
) -> @lepusa.CommandRegistry {
  registry
  .register_fn("window.close", permission=Window, handler=payload => {
    handle_control(policy, state, payload, action=Close)
  })
  .register_fn("window.focus", permission=Window, handler=payload => {
    handle_control(policy, state, payload, action=Focus)
  })
  .register_fn("window.hide", permission=Window, handler=payload => {
    handle_control(policy, state, payload, action=Hide)
  })
  .register_fn("window.maximize", permission=Window, handler=payload => {
    handle_control(policy, state, payload, action=Maximize)
  })
  .register_fn("window.minimize", permission=Window, handler=payload => {
    handle_control(policy, state, payload, action=Minimize)
  })
  .register_fn("window.setFullscreen", permission=Window, handler=payload => {
    handle_control(policy, state, payload, action=SetFullscreen)
  })
  .register_fn("window.setPosition", permission=Window, handler=payload => {
    handle_control(policy, state, payload, action=SetPosition)
  })
  .register_fn("window.setSize", permission=Window, handler=payload => {
    handle_control(policy, state, payload, action=SetSize)
  })
  .register_fn("window.setTitle", permission=Window, handler=payload => {
    handle_control(policy, state, payload, action=SetTitle)
  })
  .register_fn("window.show", permission=Window, handler=payload => {
    handle_control(policy, state, payload, action=Show)
  })
  .register_fn("window.unmaximize", permission=Window, handler=payload => {
    handle_control(policy, state, payload, action=Unmaximize)
  })
}

///|
fn handle_control(
  policy : WindowControlPolicy,
  state : WindowControlState,
  payload : String,
  action~ : WindowControlAction,
) -> Result[String, String] {
  let window_label = match window_label_from_payload(payload) {
    Ok(label) => label
    Err(problem) => return Err(problem)
  }
  if !policy.allows(window_label) {
    return Err("window control is not allowed for window: \{window_label}")
  }
  let operation = WindowControlOperation::new(window_label~, action~, payload~)
  state.record(operation)
  Ok(
    Json::object({
      "status": Json::string("queued"),
      "windowLabel": Json::string(window_label),
      "action": Json::string(action.name()),
      "operation": operation.to_json_value(),
    }).stringify(),
  )
}

///|
fn WindowControlOperation::to_json_value(self : WindowControlOperation) -> Json {
  Json::object({
    "windowLabel": Json::string(self.window_label),
    "action": Json::string(self.action.name()),
    "payload": Json::string(self.payload),
  })
}

///|
fn window_label_from_payload(payload : String) -> Result[String, String] {
  if payload == "" {
    return Ok("main")
  }
  let json = @json.parse(payload) catch {
    error => return Err("invalid window control payload: \{error}")
  }
  match json {
    String(label) => validate_window_label(label)
    Object(object) =>
      validate_window_label(
        string_field(object, "windowLabel").unwrap_or("main"),
      )
    _ => Err("window control payload must be a string or object")
  }
}

///|
fn validate_window_label(label : String) -> Result[String, String] {
  if label == "" {
    Err("window control windowLabel is required")
  } else if invalid_window_label(label) {
    Err("window control windowLabel is invalid: \{label}")
  } else {
    Ok(label)
  }
}

///|
fn invalid_window_label(label : String) -> Bool {
  label.contains("/") || label.contains("\\") || label.contains("..")
}

///|
fn string_field(object : Map[String, Json], key : String) -> String? {
  match object.get(key) {
    Some(String(value)) => Some(value)
    _ => None
  }
}
