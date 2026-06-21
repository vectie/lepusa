///|
let frontend_event_plugin = "__lepusa"

///|
let frontend_event_emit_command = "event.emit"

///|
fn is_frontend_event_emit_request(request : @lepusa.InvokeRequest) -> Bool {
  request.plugin() == frontend_event_plugin &&
  request.command() == frontend_event_emit_command
}

///|
fn RuntimeHost::dispatch_with_operations(
  self : RuntimeHost,
  request : @lepusa.InvokeRequest,
) -> (@lepusa.InvokeResponse, Array[NativeExecutableOperation]) {
  if is_frontend_event_emit_request(request) {
    self.dispatch_frontend_event_emit(request)
  } else {
    let response = self.dispatch(request)
    let operations = self.dispatch_followup_operations(request, response)
    (response, operations)
  }
}

///|
async fn RuntimeHost::dispatch_with_operations_async(
  self : RuntimeHost,
  request : @lepusa.InvokeRequest,
) -> (@lepusa.InvokeResponse, Array[NativeExecutableOperation]) {
  if is_frontend_event_emit_request(request) {
    self.dispatch_frontend_event_emit(request)
  } else {
    let response = self.dispatch_async(request)
    let operations = self.dispatch_followup_operations(request, response)
    (response, operations)
  }
}

///|
fn RuntimeHost::dispatch_frontend_event_emit(
  self : RuntimeHost,
  request : @lepusa.InvokeRequest,
) -> (@lepusa.InvokeResponse, Array[NativeExecutableOperation]) {
  let request_problems = request.validate()
  if !request_problems.is_empty() {
    return (
      @lepusa.InvokeResponse::invalid_request(request.id(), request_problems[0]),
      [],
    )
  }
  match frontend_event_action_from_request(request) {
    Err(response) => (response, [])
    Ok(action) =>
      match self.snapshot() {
        Err(problems) =>
          (
            @lepusa.InvokeResponse::handler_error(
              request.id(),
              problems.join("; "),
              route=request.route(),
            ),
            [],
          )
        Ok(session) =>
          match session.apply_actions([action]) {
            Err(problems) =>
              (
                @lepusa.InvokeResponse::handler_error(
                  request.id(),
                  problems.join("; "),
                  route=request.route(),
                ),
                [],
              )
            Ok(step) => {
              self.replace_session(step.session())
              let operations = native_executable_operations_from_runtime(
                step.operations(),
              )
              (
                @lepusa.InvokeResponse::ok(
                  request.id(),
                  "{\"delivered\":\{operations.length()}}",
                ),
                operations,
              )
            }
          }
      }
  }
}

///|
fn native_executable_operations_from_runtime(
  operations : Array[RuntimeOperation],
) -> Array[NativeExecutableOperation] {
  let native : Array[NativeExecutableOperation] = []
  for operation in operations {
    native.push(NativeOperation::from_runtime(operation).executable())
  }
  native
}

///|
fn RuntimeHost::dispatch_followup_operations(
  self : RuntimeHost,
  request : @lepusa.InvokeRequest,
  response : @lepusa.InvokeResponse,
) -> Array[NativeExecutableOperation] {
  let operations : Array[NativeExecutableOperation] = []
  for operation in self.window_open_followup_operations(request, response) {
    operations.push(operation)
  }
  for operation in self.window_close_followup_operations(request, response) {
    operations.push(operation)
  }
  operations
}

///|
fn RuntimeHost::window_open_followup_operations(
  self : RuntimeHost,
  request : @lepusa.InvokeRequest,
  response : @lepusa.InvokeResponse,
) -> Array[NativeExecutableOperation] {
  if request.plugin() != "window" || request.command() != "open" {
    return []
  }
  match response.payload() {
    None => []
    Some(_) =>
      match @lepusa.WindowConfig::parse_open_payload(request.payload()) {
        Err(_) => []
        Ok(window) =>
          match self.snapshot() {
            Err(_) => []
            Ok(session) =>
              match session.open_window(window) {
                Err(_) => []
                Ok(step) => {
                  self.replace_session(step.session())
                  native_executable_operations_from_runtime(step.operations())
                }
              }
          }
      }
  }
}

///|
fn RuntimeHost::window_close_followup_operations(
  self : RuntimeHost,
  request : @lepusa.InvokeRequest,
  response : @lepusa.InvokeResponse,
) -> Array[NativeExecutableOperation] {
  if request.plugin() != "window" || request.command() != "close" {
    return []
  }
  if window_followup_operation_action(response) != "close" {
    return []
  }
  let window_label = window_followup_operation_label(response)
  if window_label == "" {
    return []
  }
  match self.snapshot() {
    Err(_) => []
    Ok(session) =>
      match session.close_window(window_label) {
        Err(_) => []
        Ok(step) => {
          self.replace_session(step.session())
          native_executable_operations_from_runtime(step.operations())
        }
      }
  }
}

///|
fn window_followup_operation_label(response : @lepusa.InvokeResponse) -> String {
  window_followup_operation_string(response, "windowLabel")
}

///|
fn window_followup_operation_action(
  response : @lepusa.InvokeResponse,
) -> String {
  window_followup_operation_string(response, "action")
}

///|
fn window_followup_operation_string(
  response : @lepusa.InvokeResponse,
  key : String,
) -> String {
  let payload = match response.payload() {
    Some(payload) => payload
    None => return ""
  }
  let parsed = @json.parse(payload) catch { _ => return "" }
  match parsed {
    Object(object) =>
      match object.get("operation") {
        Some(Object(operation)) =>
          match operation.get(key) {
            Some(String(value)) => value
            _ => ""
          }
        _ => ""
      }
    _ => ""
  }
}

///|
fn frontend_event_action_from_request(
  request : @lepusa.InvokeRequest,
) -> Result[@lepusa.RuntimeAction, @lepusa.InvokeResponse] {
  let parsed = @json.parse(request.payload()) catch {
    error =>
      return Err(
        @lepusa.InvokeResponse::invalid_request(
          request.id(),
          "invalid frontend event json: \{error}",
        ),
      )
  }
  match parsed {
    Object(object) => {
      let name = frontend_event_name(object)
      if name == "" {
        return Err(
          @lepusa.InvokeResponse::invalid_request(
            request.id(),
            "frontend event name is required",
          ),
        )
      }
      match frontend_event_target(object.get("target")) {
        Err(problem) =>
          Err(@lepusa.InvokeResponse::invalid_request(request.id(), problem))
        Ok(target) =>
          match frontend_event_authorize_target(request, target) {
            Some(response) => Err(response)
            None =>
              Ok(
                RuntimeEmit(
                  target,
                  @lepusa.Event::new(
                    name,
                    payload=frontend_event_payload(object),
                  ),
                ),
              )
          }
      }
    }
    _ =>
      Err(
        @lepusa.InvokeResponse::invalid_request(
          request.id(),
          "frontend event json must be an object",
        ),
      )
  }
}

///|
fn frontend_event_authorize_target(
  request : @lepusa.InvokeRequest,
  target : @lepusa.EventTarget,
) -> @lepusa.InvokeResponse? {
  match target {
    AppTarget => None
    WindowTarget(label) | WebviewTarget(label) =>
      if label == request.window_label() {
        None
      } else {
        Some(
          @lepusa.InvokeResponse::permission_denied(
            request.id(),
            request.route(),
          ),
        )
      }
  }
}

///|
fn frontend_event_name(object : Map[String, Json]) -> String {
  match object.get("name") {
    Some(String(value)) => value
    _ =>
      match object.get("event") {
        Some(String(value)) => value
        _ => ""
      }
  }
}

///|
fn frontend_event_payload(object : Map[String, Json]) -> String {
  match object.get("payload") {
    None | Some(Null) => ""
    Some(String(value)) => value
    Some(value) => value.stringify()
  }
}

///|
fn frontend_event_target(value : Json?) -> Result[@lepusa.EventTarget, String] {
  match value {
    None | Some(Null) => Ok(AppTarget)
    Some(String(label)) =>
      if label == "" {
        Err("frontend event target label is required")
      } else {
        Ok(WindowTarget(label))
      }
    Some(Object(object)) => {
      let kind = match object.get("kind") {
        Some(String(value)) => value.to_lower()
        _ => "app"
      }
      let label = match object.get("label") {
        Some(String(value)) => value
        _ => ""
      }
      match kind {
        "app" => Ok(AppTarget)
        "window" =>
          if label == "" {
            Err("frontend event target window label is required")
          } else {
            Ok(WindowTarget(label))
          }
        "webview" =>
          if label == "" {
            Err("frontend event target webview label is required")
          } else {
            Ok(WebviewTarget(label))
          }
        _ => Err("unknown frontend event target kind: \{kind}")
      }
    }
    _ => Err("frontend event target must be an object, string, or null")
  }
}

///|
fn NativeRuntime::dispatch_with_operations(
  self : NativeRuntime,
  request : @lepusa.InvokeRequest,
) -> (@lepusa.InvokeResponse, Array[NativeExecutableOperation]) {
  self.host.dispatch_with_operations(request)
}

///|
async fn NativeRuntime::dispatch_with_operations_async(
  self : NativeRuntime,
  request : @lepusa.InvokeRequest,
) -> (@lepusa.InvokeResponse, Array[NativeExecutableOperation]) {
  self.host.dispatch_with_operations_async(request)
}
