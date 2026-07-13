///|
pub struct BrowserHostState {
  pending : Map[String, String]
  terminal : Map[String, String]
}

///|
pub fn BrowserHostState::new() -> BrowserHostState {
  { pending: {}, terminal: {} }
}

///|
pub fn plugin() -> @lepusa.Plugin {
  @lepusa.Plugin::new("browserHost")
  .command_sync("execute")
  .command_sync("complete")
  .command_sync("captureScreenshot")
  .command_sync("status")
}

///|
pub fn capability(name? : String = "browser-host") -> @lepusa.Capability {
  @lepusa.Capability::new(name)
  .command("browserHost.execute")
  .command("browserHost.complete")
  .command("browserHost.captureScreenshot")
  .command("browserHost.status")
}

///|
pub fn capability_for_window(
  window_label : String,
  name? : String = "browser-host",
) -> @lepusa.Capability {
  capability(name~).window(window_label)
}

///|
pub fn registry(
  state? : BrowserHostState = BrowserHostState::new(),
) -> @lepusa.CommandRegistry {
  register(@lepusa.CommandRegistry::new(), state~)
}

///|
pub fn register(
  registry : @lepusa.CommandRegistry,
  state? : BrowserHostState = BrowserHostState::new(),
) -> @lepusa.CommandRegistry {
  registry
  .register_fn("browserHost.execute", handler=fn(payload) {
    handle_execute(state, payload)
  })
  .register_fn("browserHost.complete", handler=fn(payload) {
    handle_complete(state, payload)
  })
  .register_fn("browserHost.captureScreenshot", handler=fn(_) {
    handle_capture_screenshot()
  })
  .register_fn("browserHost.status", handler=fn(_) { handle_status(state) })
}

///|
#cfg(target="native")
extern "c" fn native_capture_visible_webview_png() -> Bytes = "lepusa_browser_host_capture_visible_webview_png"

///|
#cfg(target="native")
fn capture_visible_webview_png() -> Bytes {
  native_capture_visible_webview_png()
}

///|
#cfg(not(target="native"))
fn capture_visible_webview_png() -> Bytes {
  b""
}

///|
fn handle_capture_screenshot() -> Result[String, String] {
  let png = capture_visible_webview_png()
  if png.length() == 0 {
    return Err("native visible-webview screenshot unavailable")
  }
  Ok(
    Json::object({
      "protocol": Json::string("lepusa-browser-host-v1"),
      "kind": Json::string("native-visible-webview-png"),
      "byte_length": Json::number(png.length().to_double()),
      "png_base64": Json::string(@base64.encode(png.view())),
    }).stringify(),
  )
}

///|
fn required_string(
  object : Map[String, Json],
  field : String,
) -> Result[String, String] {
  match object.get(field) {
    Some(String(value)) if value != "" => Ok(value)
    _ => Err("browser host \{field} is required")
  }
}

///|
fn command_object(
  payload : String,
) -> Result[(Map[String, Json], Json), String] {
  let parsed = @json.parse(payload) catch {
    error => return Err("invalid browser host command: \{error}")
  }
  match parsed {
    Object(object) => {
      for
        field in [
          "request_id", "session_id", "action_id", "code_revision", "authority_envelope_id",
          "capability_digest", "semantic_target",
        ] {
        match required_string(object, field) {
          Ok(_) => ()
          Err(problem) => return Err(problem)
        }
      }
      match object.get("allowed_origins") {
        Some(Array(_)) => Ok((object, parsed))
        _ => Err("browser host allowed_origins is required")
      }
    }
    _ => Err("browser host command must be an object")
  }
}

///|
fn handle_execute(
  state : BrowserHostState,
  payload : String,
) -> Result[String, String] {
  let (command, command_json) = match command_object(payload) {
    Ok(value) => value
    Err(problem) => return Err(problem)
  }
  let request_id = match required_string(command, "request_id") {
    Ok(value) => value
    Err(problem) => return Err(problem)
  }
  match state.terminal.get(request_id) {
    Some(response) => Ok(response)
    None => {
      state.pending[request_id] = payload
      Ok(
        Json::object({
          "protocol": Json::string("lepusa-browser-host-v1"),
          "status": Json::string("ready-in-originating-frame"),
          "request_id": Json::string(request_id),
          "command": command_json,
        }).stringify(),
      )
    }
  }
}

///|
fn handle_complete(
  state : BrowserHostState,
  payload : String,
) -> Result[String, String] {
  let result_json = @json.parse(payload) catch {
    error => return Err("invalid browser host result: \{error}")
  }
  let result = match result_json {
    Object(object) => object
    _ => return Err("browser host result must be an object")
  }
  let request_id = match required_string(result, "request_id") {
    Ok(value) => value
    Err(problem) => return Err(problem)
  }
  match state.terminal.get(request_id) {
    Some(response) => return Ok(response)
    None => ()
  }
  let command = match state.pending.get(request_id) {
    Some(command_payload) =>
      match command_object(command_payload) {
        Ok((command, _)) => command
        Err(problem) => return Err(problem)
      }
    None => return Err("browser host request is not pending")
  }
  for
    field in [
      "session_id", "action_id", "code_revision", "authority_envelope_id", "capability_digest",
    ] {
    let result_value = match required_string(result, field) {
      Ok(value) => value
      Err(problem) => return Err(problem)
    }
    let command_value = match required_string(command, field) {
      Ok(value) => value
      Err(problem) => return Err(problem)
    }
    if result_value != command_value {
      return Err("browser host result \{field} mismatch")
    }
  }
  for field in ["before_state_digest", "after_state_digest"] {
    match required_string(result, field) {
      Ok(_) => ()
      Err(problem) => return Err(problem)
    }
  }
  result["host_receipt_id"] = Json::string("lepusa-native-\{request_id}")
  let response = Json::object({
    "protocol": Json::string("lepusa-browser-host-v1"),
    "status": Json::string("completed-in-originating-frame"),
    "request_id": Json::string(request_id),
    "result": result_json,
  }).stringify()
  state.pending.remove(request_id)
  state.terminal[request_id] = response
  Ok(response)
}

///|
fn handle_status(state : BrowserHostState) -> Result[String, String] {
  Ok(
    Json::object({
      "protocol": Json::string("lepusa-browser-host-v1"),
      "route_available": Json::boolean(true),
      "pending": Json::number(state.pending.length().to_double()),
      "terminal": Json::number(state.terminal.length().to_double()),
    }).stringify(),
  )
}
