///|
pub struct SingleInstancePolicy {
  key : String
  primary_window : String?
  forward_args : Bool
  forward_urls : Bool
} derive(Debug, Eq)

///|
pub fn SingleInstancePolicy::new(
  key~ : String,
  primary_window? : String,
  forward_args? : Bool = true,
  forward_urls? : Bool = true,
) -> SingleInstancePolicy {
  { key, primary_window, forward_args, forward_urls }
}

///|
pub fn SingleInstancePolicy::key(self : SingleInstancePolicy) -> String {
  self.key
}

///|
pub fn SingleInstancePolicy::primary_window(
  self : SingleInstancePolicy,
) -> String? {
  self.primary_window
}

///|
pub fn SingleInstancePolicy::forward_args(self : SingleInstancePolicy) -> Bool {
  self.forward_args
}

///|
pub fn SingleInstancePolicy::forward_urls(self : SingleInstancePolicy) -> Bool {
  self.forward_urls
}

///|
pub fn SingleInstancePolicy::validate(
  self : SingleInstancePolicy,
) -> Array[String] {
  let problems : Array[String] = []
  if self.key == "" {
    problems.push("single instance key is required")
  } else if invalid_key(self.key) {
    problems.push("single instance key is invalid: \{self.key}")
  }
  match self.primary_window {
    Some(label) =>
      if label == "" {
        problems.push("single instance primary window is required")
      }
    None => ()
  }
  problems
}

///|
pub fn plugin() -> @lepusa.Plugin {
  @lepusa.Plugin::new("singleInstance")
  .command_sync("status", permission=SingleInstance)
  .command_sync("acquire", permission=SingleInstance)
  .command_sync("release", permission=SingleInstance)
  .command_sync("focus", permission=SingleInstance)
  .command_event("onSecondLaunch", permission=SingleInstance)
}

///|
pub fn capability(name? : String = "single-instance") -> @lepusa.Capability {
  @lepusa.Capability::new(name).permission(SingleInstance)
}

///|
pub fn capability_for_window(
  window_label : String,
  name? : String = "single-instance",
) -> @lepusa.Capability {
  capability(name~).window(window_label)
}

///|
pub struct SingleInstanceState {
  mut acquired : Bool
  mut focused_count : Int
  second_launches : Array[String]
}

///|
pub fn SingleInstanceState::new(
  acquired? : Bool = false,
) -> SingleInstanceState {
  { acquired, focused_count: 0, second_launches: [] }
}

///|
pub fn SingleInstanceState::acquired(self : SingleInstanceState) -> Bool {
  self.acquired
}

///|
pub fn SingleInstanceState::focused_count(self : SingleInstanceState) -> Int {
  self.focused_count
}

///|
pub fn SingleInstanceState::second_launches(
  self : SingleInstanceState,
) -> Array[String] {
  self.second_launches.copy()
}

///|
pub fn registry(
  policy? : SingleInstancePolicy = SingleInstancePolicy::new(key="lepusa"),
  state? : SingleInstanceState = SingleInstanceState::new(),
) -> @lepusa.CommandRegistry {
  register(@lepusa.CommandRegistry::new(), policy~, state~)
}

///|
pub fn register(
  registry : @lepusa.CommandRegistry,
  policy? : SingleInstancePolicy = SingleInstancePolicy::new(key="lepusa"),
  state? : SingleInstanceState = SingleInstanceState::new(),
) -> @lepusa.CommandRegistry {
  registry
  .register_fn("singleInstance.status", permission=SingleInstance, handler=_ => {
    handle_status(policy, state)
  })
  .register_fn("singleInstance.acquire", permission=SingleInstance, handler=payload => {
    handle_acquire(policy, state, payload)
  })
  .register_fn("singleInstance.release", permission=SingleInstance, handler=_ => {
    handle_release(policy, state)
  })
  .register_fn("singleInstance.focus", permission=SingleInstance, handler=_ => {
    handle_focus(policy, state)
  })
}

///|
fn handle_status(
  policy : SingleInstancePolicy,
  state : SingleInstanceState,
) -> Result[String, String] {
  Ok(single_instance_json(policy, state, status="ready").stringify())
}

///|
fn handle_acquire(
  policy : SingleInstancePolicy,
  state : SingleInstanceState,
  payload : String,
) -> Result[String, String] {
  let launch = match decode_launch_payload(payload) {
    Ok(value) => value
    Err(problem) => return Err(problem)
  }
  if state.acquired {
    if launch != "" {
      state.second_launches.push(launch)
    }
    Ok(single_instance_json(policy, state, status="secondary").stringify())
  } else {
    state.acquired = true
    Ok(single_instance_json(policy, state, status="primary").stringify())
  }
}

///|
fn handle_release(
  policy : SingleInstancePolicy,
  state : SingleInstanceState,
) -> Result[String, String] {
  state.acquired = false
  Ok(single_instance_json(policy, state, status="released").stringify())
}

///|
fn handle_focus(
  policy : SingleInstancePolicy,
  state : SingleInstanceState,
) -> Result[String, String] {
  state.focused_count += 1
  Ok(single_instance_json(policy, state, status="focused").stringify())
}

///|
fn decode_launch_payload(payload : String) -> Result[String, String] {
  if payload == "" {
    return Ok("")
  }
  let json = @json.parse(payload) catch {
    error => return Err("invalid single instance acquire payload: \{error}")
  }
  match json {
    String(value) => Ok(value)
    Object(object) => Ok(string_field(object, "launch").unwrap_or(""))
    _ => Err("single instance acquire payload must be a string or object")
  }
}

///|
fn single_instance_json(
  policy : SingleInstancePolicy,
  state : SingleInstanceState,
  status~ : String,
) -> Json {
  Json::object({
    "key": Json::string(policy.key()),
    "primaryWindow": optional_string_json(policy.primary_window()),
    "acquired": Json::boolean(state.acquired()),
    "status": Json::string(status),
    "focusedCount": Json::number(
      state.focused_count().to_double(),
      repr=state.focused_count().to_string(),
    ),
    "forwardArgs": Json::boolean(policy.forward_args()),
    "forwardUrls": Json::boolean(policy.forward_urls()),
    "secondLaunches": string_array_json(state.second_launches()),
  })
}

///|
fn optional_string_json(value : String?) -> Json {
  match value {
    Some(value) => Json::string(value)
    None => Json::null()
  }
}

///|
fn string_array_json(values : Array[String]) -> Json {
  Json::array(values.map(fn(value) { Json::string(value) }))
}

///|
fn string_field(object : Map[String, Json], key : String) -> String? {
  match object.get(key) {
    Some(String(value)) => Some(value)
    _ => None
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
