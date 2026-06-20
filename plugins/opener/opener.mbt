///|
pub fn plugin() -> @lepusa.Plugin {
  @lepusa.Plugin::new("opener")
  .command_sync("openUrl", permission=Opener)
  .command_sync("openPath", permission=Opener)
  .command_sync("revealPath", permission=Opener)
}

///|
pub fn capability(name? : String = "opener") -> @lepusa.Capability {
  @lepusa.Capability::new(name).permission(Opener)
}

///|
pub fn capability_for_window(
  window_label : String,
  name? : String = "opener",
) -> @lepusa.Capability {
  capability(name~).window(window_label)
}

///|
#cfg(target="native")
#borrow(target)
extern "c" fn native_open_url(target : Bytes) -> Int = "lepusa_opener_open_url"

///|
#cfg(target="native")
#borrow(target)
extern "c" fn native_open_path(target : Bytes) -> Int = "lepusa_opener_open_path"

///|
#cfg(target="native")
#borrow(target)
extern "c" fn native_reveal_path(target : Bytes) -> Int = "lepusa_opener_reveal_path"

///|
pub fn registry() -> @lepusa.CommandRegistry {
  register(@lepusa.CommandRegistry::new())
}

///|
pub fn register(registry : @lepusa.CommandRegistry) -> @lepusa.CommandRegistry {
  registry
  .register_fn("opener.openUrl", permission=Opener, handler=handle_open_url)
  .register_fn("opener.openPath", permission=Opener, handler=handle_open_path)
  .register_fn(
    "opener.revealPath",
    permission=Opener,
    handler=handle_reveal_path,
  )
}

///|
fn handle_open_url(payload : String) -> Result[String, String] {
  match decode_target_payload(payload, field="url", context="opener openUrl") {
    Ok(target) => opener_result_json("openUrl", target, run_open_url)
    Err(problem) => Err(problem)
  }
}

///|
fn handle_open_path(payload : String) -> Result[String, String] {
  match
    decode_target_payload(payload, field="path", context="opener openPath") {
    Ok(target) => opener_result_json("openPath", target, run_open_path)
    Err(problem) => Err(problem)
  }
}

///|
fn handle_reveal_path(payload : String) -> Result[String, String] {
  match
    decode_target_payload(payload, field="path", context="opener revealPath") {
    Ok(target) => opener_result_json("revealPath", target, run_reveal_path)
    Err(problem) => Err(problem)
  }
}

///|
#cfg(target="native")
fn run_open_url(target : Bytes) -> Int {
  native_open_url(target)
}

///|
#cfg(not(target="native"))
fn run_open_url(_target : Bytes) -> Int {
  2
}

///|
#cfg(target="native")
fn run_open_path(target : Bytes) -> Int {
  native_open_path(target)
}

///|
#cfg(not(target="native"))
fn run_open_path(_target : Bytes) -> Int {
  2
}

///|
#cfg(target="native")
fn run_reveal_path(target : Bytes) -> Int {
  native_reveal_path(target)
}

///|
#cfg(not(target="native"))
fn run_reveal_path(_target : Bytes) -> Int {
  2
}

///|
fn opener_result_json(
  action : String,
  target : String,
  run : (Bytes) -> Int,
) -> Result[String, String] {
  match run(@utf8.encode(target)) {
    0 =>
      Ok(
        Json::object({
          "action": Json::string(action),
          "target": Json::string(target),
          "status": Json::string("launched"),
        }).stringify(),
      )
    2 => Err("opener \{action} is unavailable on this platform")
    code => Err("opener \{action} failed: code \{code}")
  }
}

///|
fn decode_target_payload(
  payload : String,
  field~ : String,
  context~ : String,
) -> Result[String, String] {
  if payload == "" {
    return Err("\{context} payload is required")
  }
  let json = @json.parse(payload) catch {
    error => return Err("invalid \{context} payload: \{error}")
  }
  let target = match json {
    String(value) => value
    Object(object) => string_field(object, field).unwrap_or("")
    _ => return Err("\{context} payload must be a string or object")
  }
  if target == "" {
    Err("\{context} target is required")
  } else {
    Ok(target)
  }
}

///|
fn string_field(object : Map[String, Json], key : String) -> String? {
  match object.get(key) {
    Some(String(value)) => Some(value)
    _ => None
  }
}
