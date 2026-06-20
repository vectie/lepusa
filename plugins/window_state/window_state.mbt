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
pub struct WindowStateFileStore {
  root : String
  store_name : String
} derive(Debug, Eq)

///|
priv struct WindowStateBackend {
  get : (String) -> Result[String?, String]
  set : (String, String) -> Result[Unit, String]
  clear : (String) -> Result[Int, String]
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
pub fn WindowStateFileStore::new(
  root~ : String,
  store_name? : String = "lepusa-window-state",
) -> WindowStateFileStore {
  { root, store_name }
}

///|
pub fn WindowStateFileStore::root(self : WindowStateFileStore) -> String {
  self.root
}

///|
pub fn WindowStateFileStore::store_name(self : WindowStateFileStore) -> String {
  self.store_name
}

///|
pub fn WindowStateFileStore::validate(
  self : WindowStateFileStore,
) -> Array[String] {
  let problems : Array[String] = []
  if self.root == "" {
    problems.push("window state file store root is required")
  }
  if self.store_name == "" {
    problems.push("window state file store name is required")
  } else if invalid_key(self.store_name) {
    problems.push("window state file store name is invalid: \{self.store_name}")
  }
  problems
}

///|
pub fn registry(
  store? : WindowStateStore = WindowStateStore::new(),
) -> @lepusa.CommandRegistry {
  register(@lepusa.CommandRegistry::new(), store~)
}

///|
pub fn file_registry(store : WindowStateFileStore) -> @lepusa.CommandRegistry {
  register_file(@lepusa.CommandRegistry::new(), store)
}

///|
pub fn register(
  registry : @lepusa.CommandRegistry,
  store? : WindowStateStore = WindowStateStore::new(),
) -> @lepusa.CommandRegistry {
  register_backend(registry, memory_backend(store))
}

///|
pub fn register_file(
  registry : @lepusa.CommandRegistry,
  store : WindowStateFileStore,
) -> @lepusa.CommandRegistry {
  register_backend(registry, file_backend(store))
}

///|
fn register_backend(
  registry : @lepusa.CommandRegistry,
  backend : WindowStateBackend,
) -> @lepusa.CommandRegistry {
  registry
  .register_fn("windowState.save", permission=WindowState, handler=payload => {
    handle_set(backend, payload, status="saved")
  })
  .register_fn("windowState.restore", permission=WindowState, handler=payload => {
    handle_get(backend, payload)
  })
  .register_fn("windowState.clear", permission=WindowState, handler=payload => {
    handle_clear(backend, payload)
  })
  .register_fn("windowState.get", permission=WindowState, handler=payload => {
    handle_get(backend, payload)
  })
  .register_fn("windowState.set", permission=WindowState, handler=payload => {
    handle_set(backend, payload, status="set")
  })
}

///|
fn handle_get(
  backend : WindowStateBackend,
  payload : String,
) -> Result[String, String] {
  match decode_window_payload(payload, context="window state get") {
    Ok(label) =>
      match (backend.get)(label) {
        Ok(Some(state)) =>
          Ok(window_state_get_json(label, state, found=true).stringify())
        Ok(None) =>
          Ok(window_state_get_json(label, "", found=false).stringify())
        Err(problem) => Err(problem)
      }
    Err(problem) => Err(problem)
  }
}

///|
fn handle_set(
  backend : WindowStateBackend,
  payload : String,
  status~ : String,
) -> Result[String, String] {
  match decode_window_payload(payload, context="window state set") {
    Ok(label) =>
      match (backend.set)(label, payload) {
        Ok(_) =>
          Ok(
            Json::object({
              "window": Json::string(label),
              "status": Json::string(status),
            }).stringify(),
          )
        Err(problem) => Err(problem)
      }
    Err(problem) => Err(problem)
  }
}

///|
fn handle_clear(
  backend : WindowStateBackend,
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
  match (backend.clear)(label) {
    Ok(cleared) =>
      Ok(
        Json::object({
          "window": Json::string(label),
          "cleared": Json::number(cleared.to_double(), repr=cleared.to_string()),
        }).stringify(),
      )
    Err(problem) => Err(problem)
  }
}

///|
fn window_state_get_json(label : String, state : String, found~ : Bool) -> Json {
  Json::object({
    "window": Json::string(label),
    "state": Json::string(state),
    "found": Json::boolean(found),
  })
}

///|
fn memory_backend(store : WindowStateStore) -> WindowStateBackend {
  {
    get: label => Ok(store.get(label)),
    set: (label, state) => {
      store.set(label, state)
      Ok(())
    },
    clear: label => Ok(store.clear(window_label=label)),
  }
}

///|
fn file_backend(store : WindowStateFileStore) -> WindowStateBackend {
  {
    get: label => file_store_get(store, label),
    set: (label, state) => file_store_set(store, label, state),
    clear: label => file_store_clear(store, label),
  }
}

///|
fn file_store_get(
  store : WindowStateFileStore,
  label : String,
) -> Result[String?, String] {
  match first_problem(store.validate()) {
    Some(problem) => Err(problem)
    None => {
      let path = store.file_path(label)
      let content = @xfs.read_file_to_string(path) catch {
        _ => return Ok(None)
      }
      Ok(Some(content))
    }
  }
}

///|
fn file_store_set(
  store : WindowStateFileStore,
  label : String,
  state : String,
) -> Result[Unit, String] {
  match first_problem(store.validate()) {
    Some(problem) => Err(problem)
    None => {
      match ensure_store_root(store.root()) {
        Err(problem) => return Err(problem)
        Ok(_) => ()
      }
      @xfs.write_string_to_file(store.file_path(label), state) catch {
        _ => return Err("could not write window state file")
      }
      Ok(())
    }
  }
}

///|
fn file_store_clear(
  store : WindowStateFileStore,
  label : String,
) -> Result[Int, String] {
  match first_problem(store.validate()) {
    Some(problem) => Err(problem)
    None =>
      if label == "" {
        clear_store_files(store)
      } else {
        let path = store.file_path(label)
        if !file_exists(path) {
          Ok(0)
        } else {
          @xfs.remove_file(path) catch {
            _ => return Err("could not delete window state file")
          }
          Ok(1)
        }
      }
  }
}

///|
fn clear_store_files(store : WindowStateFileStore) -> Result[Int, String] {
  if !file_exists(store.root()) {
    return Ok(0)
  }
  let entries = @xfs.read_dir(store.root()) catch { _ => return Ok(0) }
  let mut cleared = 0
  let prefix = store.file_prefix()
  for entry in entries {
    if entry.has_prefix(prefix) && entry.has_suffix(".json") {
      @xfs.remove_file(join_path(store.root(), entry)) catch {
        _ => return Err("could not delete window state file")
      }
      cleared += 1
    }
  }
  Ok(cleared)
}

///|
fn WindowStateFileStore::file_path(
  self : WindowStateFileStore,
  label : String,
) -> String {
  join_path(self.root, self.file_prefix() + label + ".json")
}

///|
fn WindowStateFileStore::file_prefix(self : WindowStateFileStore) -> String {
  self.store_name + "-"
}

///|
fn ensure_store_root(root : String) -> Result[Unit, String] {
  if file_exists(root) {
    return Ok(())
  }
  @xfs.create_dir(root) catch {
    _ => return Err("could not create window state directory")
  }
  Ok(())
}

///|
fn file_exists(path : String) -> Bool {
  let is_dir = @xfs.is_dir(path) catch { _ => false }
  if is_dir {
    true
  } else {
    let _ = @xfs.read_file_to_bytes(path) catch { _ => return false }
    true
  }
}

///|
fn join_path(root : String, name : String) -> String {
  if root.has_suffix("/") {
    root + name
  } else {
    root + "/" + name
  }
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
fn first_problem(problems : Array[String]) -> String? {
  if problems.length() == 0 {
    None
  } else {
    Some(problems[0])
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
