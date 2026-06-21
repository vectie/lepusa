///|
let runtime_control_plugin = "__lepusa"

///|
fn InvokeRequest::is_runtime_control(self : InvokeRequest) -> Bool {
  self.plugin() == runtime_control_plugin
}

///|
fn AppManager::dispatch_runtime_control(
  self : AppManager,
  request : InvokeRequest,
) -> InvokeResponse? {
  if !request.is_runtime_control() {
    return None
  }
  match request.command() {
    "event.emit" => Some(self.dispatch_runtime_event_emit(request))
    "stream.drain" => Some(self.dispatch_runtime_stream_drain(request))
    "stream.cancel" => Some(self.dispatch_runtime_stream_cancel(request))
    "resource.close" => Some(self.dispatch_runtime_resource_close(request))
    command =>
      Some(
        InvokeResponse::unknown_command(
          request.id(),
          "\{runtime_control_plugin}.\{command}",
        ),
      )
  }
}

///|
fn AppManager::dispatch_runtime_event_emit(
  self : AppManager,
  request : InvokeRequest,
) -> InvokeResponse {
  match runtime_control_object(request) {
    Err(response) => response
    Ok(object) => {
      let name = runtime_control_string_or(object, "name", "event")
      if name == "" {
        return InvokeResponse::invalid_request(
          request.id(),
          "runtime event name is required",
        )
      }
      match runtime_control_event_target(object.get("target")) {
        Err(problem) => InvokeResponse::invalid_request(request.id(), problem)
        Ok(target) =>
          match runtime_control_authorize_event_target(request, target) {
            Some(response) => response
            None =>
              match
                self.emit(
                  Event::new(name, payload=runtime_control_payload(object)),
                  target~,
                ) {
                Ok(deliveries) =>
                  InvokeResponse::ok(
                    request.id(),
                    "{\"delivered\":\{deliveries.length()}}",
                  )
                Err(problems) =>
                  InvokeResponse::handler_error(
                    request.id(),
                    problems.join("; "),
                    route=request.route(),
                  )
              }
          }
      }
    }
  }
}

///|
fn AppManager::dispatch_runtime_stream_drain(
  self : AppManager,
  request : InvokeRequest,
) -> InvokeResponse {
  match runtime_control_channel_id(request) {
    Err(response) => response
    Ok(channel_id) =>
      match self.runtime_control_authorize_resource(request, channel_id) {
        Some(response) => response
        None =>
          match self.drain_channel(channel_id) {
            Ok(messages) =>
              InvokeResponse::ok(
                request.id(),
                [
                  "{",
                  "\"channelId\":\{channel_id.json_string()},",
                  "\"messages\":[\{messages.map(fn(message) { message.to_json() }).join(",")}]",
                  "}",
                ].join(""),
              )
            Err(problem) =>
              InvokeResponse::handler_error(
                request.id(),
                problem,
                route=request.route(),
              )
          }
      }
  }
}

///|
fn AppManager::dispatch_runtime_stream_cancel(
  self : AppManager,
  request : InvokeRequest,
) -> InvokeResponse {
  match runtime_control_channel_id(request) {
    Err(response) => response
    Ok(channel_id) =>
      match self.runtime_control_authorize_resource(request, channel_id) {
        Some(response) => response
        None =>
          match self.cancel_channel(channel_id) {
            Ok(message) =>
              InvokeResponse::ok(
                request.id(),
                [
                  "{",
                  "\"channelId\":\{channel_id.json_string()},",
                  "\"message\":\{message.to_json()}",
                  "}",
                ].join(""),
              )
            Err(problem) =>
              InvokeResponse::handler_error(
                request.id(),
                problem,
                route=request.route(),
              )
          }
      }
  }
}

///|
fn AppManager::dispatch_runtime_resource_close(
  self : AppManager,
  request : InvokeRequest,
) -> InvokeResponse {
  match runtime_control_object(request) {
    Err(response) => response
    Ok(object) => {
      let id = runtime_control_string_or(object, "id", "channelId")
      if id == "" {
        return InvokeResponse::invalid_request(
          request.id(),
          "runtime resource id is required",
        )
      }
      match self.runtime_control_authorize_resource(request, id) {
        Some(response) => response
        None => {
          let result = match runtime_control_string(object, "kind") {
            Some(kind) =>
              self.close_resource_handle(ResourceHandle::new(id~, kind~))
            None => self.close_resource(id)
          }
          match result {
            Ok(resource) =>
              InvokeResponse::ok(
                request.id(),
                ["{", "\"closed\":\{resource.to_json()}", "}"].join(""),
              )
            Err(problem) =>
              InvokeResponse::handler_error(
                request.id(),
                problem,
                route=request.route(),
              )
          }
        }
      }
    }
  }
}

///|
fn AppManager::runtime_control_authorize_resource(
  self : AppManager,
  request : InvokeRequest,
  resource_id : String,
) -> InvokeResponse? {
  match self.resource(resource_id) {
    None => None
    Some(resource) =>
      match runtime_control_resource_window(resource) {
        Some(window_label) =>
          if window_label == request.window_label() {
            None
          } else {
            Some(
              InvokeResponse::permission_denied(request.id(), request.route()),
            )
          }
        None =>
          Some(InvokeResponse::permission_denied(request.id(), request.route()))
      }
  }
}

///|
fn runtime_control_authorize_event_target(
  request : InvokeRequest,
  target : EventTarget,
) -> InvokeResponse? {
  match target {
    AppTarget => None
    WindowTarget(label) | WebviewTarget(label) =>
      if label == request.window_label() {
        None
      } else {
        Some(InvokeResponse::permission_denied(request.id(), request.route()))
      }
  }
}

///|
fn runtime_control_resource_window(resource : ResourceEntry) -> String? {
  let parsed = @json.parse(resource.metadata()) catch { _ => return None }
  match parsed {
    Object(object) => runtime_control_string(object, "window")
    _ => None
  }
}

///|
fn runtime_control_channel_id(
  request : InvokeRequest,
) -> Result[String, InvokeResponse] {
  match runtime_control_object(request) {
    Err(response) => Err(response)
    Ok(object) => {
      let channel_id = runtime_control_string_or(object, "channelId", "id")
      if channel_id == "" {
        Err(
          InvokeResponse::invalid_request(
            request.id(),
            "runtime stream channelId is required",
          ),
        )
      } else {
        Ok(channel_id)
      }
    }
  }
}

///|
fn runtime_control_object(
  request : InvokeRequest,
) -> Result[Map[String, Json], InvokeResponse] {
  let parsed = @json.parse(request.payload()) catch {
    error =>
      return Err(
        InvokeResponse::invalid_request(
          request.id(),
          "invalid runtime control json: \{error}",
        ),
      )
  }
  match parsed {
    Object(object) => Ok(object)
    _ =>
      Err(
        InvokeResponse::invalid_request(
          request.id(),
          "runtime control payload must be an object",
        ),
      )
  }
}

///|
fn runtime_control_string(object : Map[String, Json], key : String) -> String? {
  match object.get(key) {
    Some(String(value)) => Some(value)
    _ => None
  }
}

///|
fn runtime_control_string_or(
  object : Map[String, Json],
  primary : String,
  fallback : String,
) -> String {
  match runtime_control_string(object, primary) {
    Some(value) => value
    None =>
      match runtime_control_string(object, fallback) {
        Some(value) => value
        None => ""
      }
  }
}

///|
fn runtime_control_payload(object : Map[String, Json]) -> String {
  match object.get("payload") {
    None | Some(Null) => ""
    Some(String(value)) => value
    Some(value) => value.stringify()
  }
}

///|
fn runtime_control_event_target(value : Json?) -> Result[EventTarget, String] {
  match value {
    None | Some(Null) => Ok(AppTarget)
    Some(String(label)) =>
      if label == "" {
        Err("runtime event target label is required")
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
            Err("runtime event target window label is required")
          } else {
            Ok(WindowTarget(label))
          }
        "webview" =>
          if label == "" {
            Err("runtime event target webview label is required")
          } else {
            Ok(WebviewTarget(label))
          }
        _ => Err("unknown runtime event target kind: \{kind}")
      }
    }
    _ => Err("runtime event target must be an object, string, or null")
  }
}
