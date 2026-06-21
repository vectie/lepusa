///|
let bundled_frontend_event_plugin = "__lepusa"

///|
let bundled_frontend_event_emit_command = "event.emit"

///|
fn bundled_is_frontend_event_emit_request(
  request : @lepusa.InvokeRequest,
) -> Bool {
  request.plugin() == bundled_frontend_event_plugin &&
  request.command() == bundled_frontend_event_emit_command
}

///|
fn BundledRuntime::dispatch_with_operations(
  self : BundledRuntime,
  request : @lepusa.InvokeRequest,
) -> (@lepusa.InvokeResponse, Array[@runtime.NativeExecutableOperation]) {
  if bundled_is_frontend_event_emit_request(request) {
    self.dispatch_frontend_event_emit(request)
  } else {
    let response = match
      self.dispatch(
        id=request.id(),
        window_label=request.window_label(),
        route=request.route(),
        payload=request.payload(),
        origin=request.origin(),
      ) {
      Ok(response) | Err(response) => response
    }
    let operations = bundled_dispatch_followup_operations(request, response)
    (response, operations)
  }
}

///|
async fn BundledRuntime::dispatch_with_operations_async(
  self : BundledRuntime,
  request : @lepusa.InvokeRequest,
) -> (@lepusa.InvokeResponse, Array[@runtime.NativeExecutableOperation]) {
  if bundled_is_frontend_event_emit_request(request) {
    self.dispatch_frontend_event_emit(request)
  } else {
    let response = match
      self.dispatch_async(
        id=request.id(),
        window_label=request.window_label(),
        route=request.route(),
        payload=request.payload(),
        origin=request.origin(),
      ) {
      Ok(response) | Err(response) => response
    }
    let operations = bundled_dispatch_followup_operations(request, response)
    (response, operations)
  }
}

///|
fn bundled_dispatch_followup_operations(
  request : @lepusa.InvokeRequest,
  response : @lepusa.InvokeResponse,
) -> Array[@runtime.NativeExecutableOperation] {
  let operations : Array[@runtime.NativeExecutableOperation] = []
  for operation in bundled_window_close_followup_operations(request, response) {
    operations.push(operation)
  }
  operations
}

///|
fn bundled_window_close_followup_operations(
  request : @lepusa.InvokeRequest,
  response : @lepusa.InvokeResponse,
) -> Array[@runtime.NativeExecutableOperation] {
  if request.plugin() != "window" || request.command() != "close" {
    return []
  }
  let response_json = @runtime.encode_invoke_response_json(response)
  let request_json = @runtime.encode_invoke_request_json(request)
  match
    @runtime.native_window_control_from_bridge_response(
      request_json, response_json,
    ) {
    Some(control) =>
      if control.action() == "close" {
        [
          @runtime.NativeExecutableOperation::close_window(
            @runtime.NativeWindowClose::new(window_label=control.window_label()),
          ),
        ]
      } else {
        []
      }
    None => []
  }
}

///|
fn BundledRuntime::dispatch_frontend_event_emit(
  self : BundledRuntime,
  request : @lepusa.InvokeRequest,
) -> (@lepusa.InvokeResponse, Array[@runtime.NativeExecutableOperation]) {
  let request_problems = request.validate()
  if !request_problems.is_empty() {
    return (
      @lepusa.InvokeResponse::invalid_request(request.id(), request_problems[0]),
      [],
    )
  }
  match bundled_frontend_event_from_request(request) {
    Err(problem) =>
      (@lepusa.InvokeResponse::invalid_request(request.id(), problem), [])
    Ok((target, event)) =>
      match self.manifest.webviews() {
        Err(problem) =>
          (
            @lepusa.InvokeResponse::handler_error(
              request.id(),
              problem,
              route=request.route(),
            ),
            [],
          )
        Ok(webviews) => {
          let operations = bundled_frontend_event_operations(
            target, event, webviews,
          )
          if operations.is_empty() {
            (
              @lepusa.InvokeResponse::handler_error(
                request.id(),
                "event target not found: \{bundled_frontend_target_name(target)}",
                route=request.route(),
              ),
              [],
            )
          } else {
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
fn bundled_frontend_event_operations(
  target : @lepusa.EventTarget,
  event : @lepusa.Event,
  webviews : Array[BundledWebView],
) -> Array[@runtime.NativeExecutableOperation] {
  let operations : Array[@runtime.NativeExecutableOperation] = []
  for webview in webviews {
    if bundled_frontend_target_matches_webview(target, webview) {
      let dispatch = @lepusa.FrontendEventDispatch::new(
        window_label=webview.label(),
        hook=webview.event_dispatch_hook(),
        event~,
      )
      operations.push(
        @runtime.NativeExecutableOperation::evaluate_script(
          @runtime.NativeEvaluationScript::new(
            window_label=dispatch.window_label(),
            script=dispatch.script(),
          ),
        ),
      )
    }
  }
  operations
}

///|
fn bundled_frontend_event_from_request(
  request : @lepusa.InvokeRequest,
) -> Result[(@lepusa.EventTarget, @lepusa.Event), String] {
  let parsed = @json.parse(request.payload()) catch {
    error => return Err("invalid frontend event json: \{error}")
  }
  match parsed {
    Object(object) => {
      let name = bundled_frontend_event_name(object)
      if name == "" {
        return Err("frontend event name is required")
      }
      match bundled_frontend_event_target(object.get("target")) {
        Err(problem) => Err(problem)
        Ok(target) =>
          Ok(
            (
              target,
              @lepusa.Event::new(
                name,
                payload=bundled_frontend_event_payload(object),
              ),
            ),
          )
      }
    }
    _ => Err("frontend event json must be an object")
  }
}

///|
fn bundled_frontend_event_name(object : Map[String, Json]) -> String {
  optional_string(object, "name").unwrap_or(
    optional_string(object, "event").unwrap_or(""),
  )
}

///|
fn bundled_frontend_event_payload(object : Map[String, Json]) -> String {
  match object.get("payload") {
    None | Some(Null) => ""
    Some(String(value)) => value
    Some(value) => value.stringify()
  }
}

///|
fn bundled_frontend_event_target(
  value : Json?,
) -> Result[@lepusa.EventTarget, String] {
  match value {
    None | Some(Null) => Ok(AppTarget)
    Some(String(label)) =>
      if label == "" {
        Err("frontend event target label is required")
      } else {
        Ok(WindowTarget(label))
      }
    Some(Object(object)) => {
      let kind = optional_string(object, "kind").unwrap_or("app").to_lower()
      let label = optional_string(object, "label").unwrap_or("")
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
fn bundled_frontend_target_matches_webview(
  target : @lepusa.EventTarget,
  webview : BundledWebView,
) -> Bool {
  match target {
    AppTarget => true
    WindowTarget(label) | WebviewTarget(label) => label == webview.label()
  }
}

///|
fn bundled_frontend_target_name(target : @lepusa.EventTarget) -> String {
  match target {
    AppTarget => "app"
    WindowTarget(label) => "window \{label}"
    WebviewTarget(label) => "webview \{label}"
  }
}
