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
    (self.dispatch(request), [])
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
    (self.dispatch_async(request), [])
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
    Err(problem) =>
      (@lepusa.InvokeResponse::invalid_request(request.id(), problem), [])
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
fn frontend_event_action_from_request(
  request : @lepusa.InvokeRequest,
) -> Result[@lepusa.RuntimeAction, String] {
  let parsed = @json.parse(request.payload()) catch {
    error => return Err("invalid frontend event json: \{error}")
  }
  match parsed {
    Object(object) => {
      let name = frontend_event_name(object)
      if name == "" {
        return Err("frontend event name is required")
      }
      match frontend_event_target(object.get("target")) {
        Err(problem) => Err(problem)
        Ok(target) =>
          Ok(
            RuntimeEmit(
              target,
              @lepusa.Event::new(name, payload=frontend_event_payload(object)),
            ),
          )
      }
    }
    _ => Err("frontend event json must be an object")
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
