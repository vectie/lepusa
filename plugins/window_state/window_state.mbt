///|
pub struct WindowStateRule {
  window_label : String
  remember_size : Bool
  remember_position : Bool
  remember_visibility : Bool
} derive(Debug, Eq)

///|
pub struct WindowStatePolicy {
  store_name : String
  rules : Array[WindowStateRule]
} derive(Debug, Eq)

///|
pub fn WindowStateRule::new(
  window_label~ : String,
  remember_size? : Bool = true,
  remember_position? : Bool = true,
  remember_visibility? : Bool = false,
) -> WindowStateRule {
  { window_label, remember_size, remember_position, remember_visibility }
}

///|
pub fn WindowStateRule::window_label(self : WindowStateRule) -> String {
  self.window_label
}

///|
pub fn WindowStateRule::remember_size(self : WindowStateRule) -> Bool {
  self.remember_size
}

///|
pub fn WindowStateRule::remember_position(self : WindowStateRule) -> Bool {
  self.remember_position
}

///|
pub fn WindowStateRule::remember_visibility(self : WindowStateRule) -> Bool {
  self.remember_visibility
}

///|
pub fn WindowStateRule::validate(self : WindowStateRule) -> Array[String] {
  let problems : Array[String] = []
  if self.window_label == "" {
    problems.push("window state label is required")
  } else if invalid_key(self.window_label) {
    problems.push("window state label is invalid: \{self.window_label}")
  }
  if !self.remember_size && !self.remember_position && !self.remember_visibility {
    problems.push("window state rule must remember at least one property")
  }
  problems
}

///|
pub fn WindowStatePolicy::new(
  store_name~ : String,
  rules? : Array[WindowStateRule] = [],
) -> WindowStatePolicy {
  { store_name, rules }
}

///|
pub fn WindowStatePolicy::store_name(self : WindowStatePolicy) -> String {
  self.store_name
}

///|
pub fn WindowStatePolicy::rules(
  self : WindowStatePolicy,
) -> Array[WindowStateRule] {
  self.rules.copy()
}

///|
pub fn WindowStatePolicy::rule(
  self : WindowStatePolicy,
  rule : WindowStateRule,
) -> WindowStatePolicy {
  let rules = self.rules.copy()
  rules.push(rule)
  { ..self, rules, }
}

///|
pub fn WindowStatePolicy::validate(self : WindowStatePolicy) -> Array[String] {
  let problems : Array[String] = []
  if self.store_name == "" {
    problems.push("window state store name is required")
  } else if invalid_key(self.store_name) {
    problems.push("window state store name is invalid: \{self.store_name}")
  }
  let seen : Array[String] = []
  for rule in self.rules {
    problems.append(rule.validate())
    let label = rule.window_label()
    if label != "" {
      if seen.contains(label) {
        problems.push("window state rule must be unique: \{label}")
      } else {
        seen.push(label)
      }
    }
  }
  problems
}

///|
pub fn plugin() -> @lepusa.Plugin {
  @lepusa.Plugin::new("windowState")
  .command_sync("save", permission=WindowState)
  .command_sync("restore", permission=WindowState)
  .command_sync("clear", permission=WindowState)
  .command_sync("get", permission=WindowState)
  .command_sync("set", permission=WindowState)
}

///|
pub fn capability(name? : String = "window-state") -> @lepusa.Capability {
  @lepusa.Capability::new(name).permission(WindowState)
}

///|
pub fn capability_for_window(
  window_label : String,
  name? : String = "window-state",
) -> @lepusa.Capability {
  capability(name~).window(window_label)
}

///|
pub struct WindowStateStore {
  states : Map[String, String]
}

///|
pub fn WindowStateStore::new() -> WindowStateStore {
  { states: {} }
}

///|
pub fn WindowStateStore::get(
  self : WindowStateStore,
  window_label : String,
) -> String? {
  self.states.get(window_label)
}

///|
pub fn WindowStateStore::set(
  self : WindowStateStore,
  window_label : String,
  state : String,
) -> Unit {
  self.states[window_label] = state
}

///|
pub fn WindowStateStore::clear(
  self : WindowStateStore,
  window_label? : String = "",
) -> Int {
  if window_label == "" {
    let count = self.states.length()
    self.states.clear()
    count
  } else {
    let existed = self.states.contains(window_label)
    self.states.remove(window_label)
    if existed {
      1
    } else {
      0
    }
  }
}

///|
pub fn registry(
  store? : WindowStateStore = WindowStateStore::new(),
) -> @lepusa.CommandRegistry {
  register(@lepusa.CommandRegistry::new(), store~)
}

///|
pub fn register(
  registry : @lepusa.CommandRegistry,
  store? : WindowStateStore = WindowStateStore::new(),
) -> @lepusa.CommandRegistry {
  registry
  .register_fn("windowState.save", permission=WindowState, handler=payload => {
    handle_set(store, payload, status="saved")
  })
  .register_fn("windowState.restore", permission=WindowState, handler=payload => {
    handle_get(store, payload)
  })
  .register_fn("windowState.clear", permission=WindowState, handler=payload => {
    handle_clear(store, payload)
  })
  .register_fn("windowState.get", permission=WindowState, handler=payload => {
    handle_get(store, payload)
  })
  .register_fn("windowState.set", permission=WindowState, handler=payload => {
    handle_set(store, payload, status="set")
  })
}

///|
fn handle_get(
  store : WindowStateStore,
  payload : String,
) -> Result[String, String] {
  match decode_window_payload(payload, context="window state get") {
    Ok(label) =>
      match store.get(label) {
        Some(state) =>
          Ok(
            Json::object({
              "window": Json::string(label),
              "state": Json::string(state),
              "found": Json::boolean(true),
            }).stringify(),
          )
        None =>
          Ok(
            Json::object({
              "window": Json::string(label),
              "state": Json::string(""),
              "found": Json::boolean(false),
            }).stringify(),
          )
      }
    Err(problem) => Err(problem)
  }
}

///|
fn handle_set(
  store : WindowStateStore,
  payload : String,
  status~ : String,
) -> Result[String, String] {
  match decode_window_payload(payload, context="window state set") {
    Ok(label) => {
      store.set(label, payload)
      Ok(
        Json::object({
          "window": Json::string(label),
          "status": Json::string(status),
        }).stringify(),
      )
    }
    Err(problem) => Err(problem)
  }
}

///|
fn handle_clear(
  store : WindowStateStore,
  payload : String,
) -> Result[String, String] {
  let label = if payload == "" {
    ""
  } else {
    match decode_window_payload(payload, context="window state clear") {
      Ok(label) => label
      Err(problem) => return Err(problem)
    }
  }
  let cleared = store.clear(window_label=label)
  Ok(
    Json::object({
      "window": Json::string(label),
      "cleared": Json::number(cleared.to_double(), repr=cleared.to_string()),
    }).stringify(),
  )
}

///|
fn decode_window_payload(
  payload : String,
  context~ : String,
) -> Result[String, String] {
  if payload == "" {
    return Err("\{context} payload is required")
  }
  try @json.parse(payload) catch {
    error => Err("invalid \{context} payload: \{error}")
  } noraise {
    String(label) => validate_window_label(label)
    Object(object) =>
      validate_window_label(required_string_field(object, "window"))
    _ => Err("\{context} payload must be a string or object")
  }
}

///|
fn validate_window_label(label : String) -> Result[String, String] {
  if label == "" {
    Err("window state label is required")
  } else if invalid_key(label) {
    Err("window state label is invalid: \{label}")
  } else {
    Ok(label)
  }
}

///|
fn required_string_field(object : Map[String, Json], key : String) -> String {
  match object.get(key) {
    Some(String(value)) => value
    _ => ""
  }
}

///|
fn invalid_key(value : String) -> Bool {
  value.contains("/") ||
  value.contains("\\") ||
  value.contains(":") ||
  value.contains(" ") ||
  value.contains("\t") ||
  value.contains("\n")
}
