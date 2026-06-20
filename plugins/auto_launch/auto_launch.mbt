///|
pub struct AutoLaunchPolicy {
  name : String
  executable : String?
  arguments : Array[String]
  open_hidden : Bool
} derive(Debug, Eq)

///|
pub struct AutoLaunchState {
  mut enabled : Bool
  mut last_action : String
} derive(Debug, Eq)

///|
pub fn AutoLaunchPolicy::new(
  name~ : String,
  executable? : String,
  arguments? : Array[String] = [],
  open_hidden? : Bool = false,
) -> AutoLaunchPolicy {
  { name, executable, arguments, open_hidden }
}

///|
pub fn AutoLaunchPolicy::name(self : AutoLaunchPolicy) -> String {
  self.name
}

///|
pub fn AutoLaunchPolicy::executable(self : AutoLaunchPolicy) -> String? {
  self.executable
}

///|
pub fn AutoLaunchPolicy::arguments(self : AutoLaunchPolicy) -> Array[String] {
  self.arguments.copy()
}

///|
pub fn AutoLaunchPolicy::open_hidden(self : AutoLaunchPolicy) -> Bool {
  self.open_hidden
}

///|
pub fn AutoLaunchPolicy::argument(
  self : AutoLaunchPolicy,
  argument : String,
) -> AutoLaunchPolicy {
  let arguments = self.arguments.copy()
  arguments.push(argument)
  { ..self, arguments, }
}

///|
pub fn AutoLaunchPolicy::validate(self : AutoLaunchPolicy) -> Array[String] {
  let problems : Array[String] = []
  if self.name == "" {
    problems.push("auto launch name is required")
  } else if invalid_name(self.name) {
    problems.push("auto launch name is invalid: \{self.name}")
  }
  match self.executable {
    Some("") => problems.push("auto launch executable is required")
    Some(path) =>
      if path.contains("\\") {
        problems.push("auto launch executable must use forward slashes")
      }
    None => ()
  }
  for argument in self.arguments {
    if argument == "" {
      problems.push("auto launch argument is required")
    }
  }
  problems
}

///|
#cfg(target="native")
extern "c" fn native_available_code() -> Int = "lepusa_auto_launch_available"

///|
#cfg(target="native")
#borrow(name)
extern "c" fn native_status_code(name : Bytes) -> Int = "lepusa_auto_launch_status"

///|
#cfg(target="native")
#borrow(name, executable, arguments)
extern "c" fn native_set_code(
  name : Bytes,
  executable : Bytes,
  arguments : Bytes,
  open_hidden : Int,
  enabled : Int,
) -> Int = "lepusa_auto_launch_set"

///|
#cfg(not(target="native"))
fn native_available_code() -> Int {
  0
}

///|
#cfg(not(target="native"))
fn native_status_code(_name : Bytes) -> Int {
  2
}

///|
#cfg(not(target="native"))
fn native_set_code(
  _name : Bytes,
  _executable : Bytes,
  _arguments : Bytes,
  _open_hidden : Int,
  _enabled : Int,
) -> Int {
  2
}

///|
pub fn native_available() -> Bool {
  native_available_code() == 1
}

///|
pub fn AutoLaunchState::new(enabled? : Bool = false) -> AutoLaunchState {
  { enabled, last_action: "status" }
}

///|
pub fn AutoLaunchState::enabled(self : AutoLaunchState) -> Bool {
  self.enabled
}

///|
pub fn AutoLaunchState::last_action(self : AutoLaunchState) -> String {
  self.last_action
}

///|
pub fn plugin() -> @lepusa.Plugin {
  @lepusa.Plugin::new("autoLaunch")
  .command_sync("status", permission=AutoLaunch)
  .command_sync("enable", permission=AutoLaunch)
  .command_sync("disable", permission=AutoLaunch)
  .command_sync("setEnabled", permission=AutoLaunch)
}

///|
pub fn capability(name? : String = "auto-launch") -> @lepusa.Capability {
  @lepusa.Capability::new(name).permission(AutoLaunch)
}

///|
pub fn capability_for_window(
  window_label : String,
  name? : String = "auto-launch",
) -> @lepusa.Capability {
  capability(name~).window(window_label)
}

///|
pub fn registry(
  policy? : AutoLaunchPolicy = AutoLaunchPolicy::new(name="lepusa"),
  state? : AutoLaunchState = AutoLaunchState::new(),
) -> @lepusa.CommandRegistry {
  register(@lepusa.CommandRegistry::new(), policy~, state~)
}

///|
pub fn native_registry(
  policy? : AutoLaunchPolicy = AutoLaunchPolicy::new(name="lepusa"),
) -> @lepusa.CommandRegistry {
  register_native(@lepusa.CommandRegistry::new(), policy~)
}

///|
pub fn register(
  registry : @lepusa.CommandRegistry,
  policy? : AutoLaunchPolicy = AutoLaunchPolicy::new(name="lepusa"),
  state? : AutoLaunchState = AutoLaunchState::new(),
) -> @lepusa.CommandRegistry {
  registry
  .register_fn("autoLaunch.status", permission=AutoLaunch, handler=_ => {
    handle_status(policy, state)
  })
  .register_fn("autoLaunch.enable", permission=AutoLaunch, handler=_ => {
    handle_set(policy, state, enabled=true, action="enable")
  })
  .register_fn("autoLaunch.disable", permission=AutoLaunch, handler=_ => {
    handle_set(policy, state, enabled=false, action="disable")
  })
  .register_fn("autoLaunch.setEnabled", permission=AutoLaunch, handler=payload => {
    handle_set_enabled(policy, state, payload)
  })
}

///|
pub fn register_native(
  registry : @lepusa.CommandRegistry,
  policy? : AutoLaunchPolicy = AutoLaunchPolicy::new(name="lepusa"),
) -> @lepusa.CommandRegistry {
  registry
  .register_fn("autoLaunch.status", permission=AutoLaunch, handler=_ => {
    handle_native_status(policy)
  })
  .register_fn("autoLaunch.enable", permission=AutoLaunch, handler=_ => {
    handle_native_set(policy, enabled=true, action="enable")
  })
  .register_fn("autoLaunch.disable", permission=AutoLaunch, handler=_ => {
    handle_native_set(policy, enabled=false, action="disable")
  })
  .register_fn("autoLaunch.setEnabled", permission=AutoLaunch, handler=payload => {
    handle_native_set_enabled(policy, payload)
  })
}

///|
fn handle_status(
  policy : AutoLaunchPolicy,
  state : AutoLaunchState,
) -> Result[String, String] {
  match first_problem(policy.validate()) {
    Some(problem) => Err(problem)
    None => Ok(auto_launch_json(policy, state, status="ready").stringify())
  }
}

///|
fn handle_set(
  policy : AutoLaunchPolicy,
  state : AutoLaunchState,
  enabled~ : Bool,
  action~ : String,
) -> Result[String, String] {
  match first_problem(policy.validate()) {
    Some(problem) => Err(problem)
    None => {
      state.enabled = enabled
      state.last_action = action
      Ok(auto_launch_json(policy, state, status="delegated").stringify())
    }
  }
}

///|
fn handle_set_enabled(
  policy : AutoLaunchPolicy,
  state : AutoLaunchState,
  payload : String,
) -> Result[String, String] {
  match decode_enabled_payload(payload) {
    Ok(enabled) =>
      match first_problem(policy.validate()) {
        Some(problem) => Err(problem)
        None => {
          state.enabled = enabled
          state.last_action = "setEnabled"
          Ok(auto_launch_json(policy, state, status="delegated").stringify())
        }
      }
    Err(problem) => Err(problem)
  }
}

///|
fn handle_native_status(policy : AutoLaunchPolicy) -> Result[String, String] {
  match first_problem(policy.validate()) {
    Some(problem) => Err(problem)
    None => {
      let status = native_status_code(@utf8.encode(policy.name()))
      match status {
        0 | 1 =>
          Ok(
            auto_launch_json(
              policy,
              AutoLaunchState::new(enabled=status == 1),
              status="ready",
              native=true,
            ).stringify(),
          )
        2 => Err("native auto launch is unavailable on this platform")
        code => Err("native auto launch status failed: code \{code}")
      }
    }
  }
}

///|
fn handle_native_set(
  policy : AutoLaunchPolicy,
  enabled~ : Bool,
  action~ : String,
) -> Result[String, String] {
  match first_problem(policy.validate()) {
    Some(problem) => Err(problem)
    None =>
      match required_executable(policy, enabled~) {
        Err(problem) => Err(problem)
        Ok(executable) => {
          let code = native_set_code(
            @utf8.encode(policy.name()),
            @utf8.encode(executable),
            @utf8.encode(policy.arguments().join("\n")),
            if policy.open_hidden() {
              1
            } else {
              0
            },
            if enabled {
              1
            } else {
              0
            },
          )
          match code {
            0 =>
              Ok(
                auto_launch_json(
                  policy,
                  { enabled, last_action: action },
                  status="native",
                  native=true,
                ).stringify(),
              )
            2 => Err("native auto launch is unavailable on this platform")
            code => Err("native auto launch \{action} failed: code \{code}")
          }
        }
      }
  }
}

///|
fn handle_native_set_enabled(
  policy : AutoLaunchPolicy,
  payload : String,
) -> Result[String, String] {
  match decode_enabled_payload(payload) {
    Ok(enabled) => handle_native_set(policy, enabled~, action="setEnabled")
    Err(problem) => Err(problem)
  }
}

///|
fn auto_launch_json(
  policy : AutoLaunchPolicy,
  state : AutoLaunchState,
  status~ : String,
  native? : Bool = false,
) -> Json {
  Json::object({
    "status": Json::string(status),
    "enabled": Json::boolean(state.enabled()),
    "lastAction": Json::string(state.last_action()),
    "name": Json::string(policy.name()),
    "executable": optional_string_json(policy.executable()),
    "arguments": Json::array(
      policy.arguments().map(fn(argument) { Json::string(argument) }),
    ),
    "openHidden": Json::boolean(policy.open_hidden()),
    "native": Json::boolean(native),
  })
}

///|
fn required_executable(
  policy : AutoLaunchPolicy,
  enabled~ : Bool,
) -> Result[String, String] {
  if !enabled {
    return Ok(policy.executable().unwrap_or(""))
  }
  match policy.executable() {
    Some(executable) =>
      if executable == "" {
        Err("native auto launch executable is required")
      } else {
        Ok(executable)
      }
    None => Err("native auto launch executable is required")
  }
}

///|
fn decode_enabled_payload(payload : String) -> Result[Bool, String] {
  if payload == "" {
    return Err("auto launch setEnabled payload is required")
  }
  let json = @json.parse(payload) catch {
    error => return Err("invalid auto launch setEnabled payload: \{error}")
  }
  match json {
    True => Ok(true)
    False => Ok(false)
    Object(object) =>
      match bool_field(object, "enabled") {
        Some(enabled) => Ok(enabled)
        None => Err("auto launch setEnabled enabled is required")
      }
    _ => Err("auto launch setEnabled payload must be a boolean or object")
  }
}

///|
fn optional_string_json(value : String?) -> Json {
  match value {
    Some(value) => Json::string(value)
    None => Json::null()
  }
}

///|
fn bool_field(object : Map[String, Json], key : String) -> Bool? {
  match object.get(key) {
    Some(True) => Some(true)
    Some(False) => Some(false)
    _ => None
  }
}

///|
fn first_problem(problems : Array[String]) -> String? {
  if problems.length() == 0 {
    None
  } else {
    Some(problems[0])
  }
}

///|
fn invalid_name(value : String) -> Bool {
  value.contains("/") ||
  value.contains("\\") ||
  value.contains(":") ||
  value.contains("\t") ||
  value.contains("\n")
}
