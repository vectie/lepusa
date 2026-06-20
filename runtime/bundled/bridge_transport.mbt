///|
pub struct BundledBridgeMessage {
  window_label : String
  response_hook : String
  message : String
} derive(Debug, Eq)

///|
pub struct BundledBridgeDispatch {
  window_label : String
  response_hook : String
  message : String
  response_json : String
  evaluation_script : String
} derive(Debug, Eq)

///|
pub struct BundledBridgeDispatchTask {
  message : BundledBridgeMessage
  route : String
  mode : @runtime.NativeBridgeDispatchMode
} derive(Debug, Eq)

///|
pub fn BundledRuntimeManifest::prepare_bridge_message(
  self : BundledRuntimeManifest,
  message : String,
  window_label? : String = "",
) -> Result[BundledBridgeMessage, Array[String]] {
  let resolved_window_label = bundled_bridge_window_label_from_message(
    message,
    window_label~,
  )
  match self.bridge_response_hook(window_label=resolved_window_label) {
    Ok((window_label, response_hook)) =>
      Ok({ window_label, response_hook, message })
    Err(problem) => Err([problem])
  }
}

///|
pub fn BundledRuntime::prepare_bridge_message(
  self : BundledRuntime,
  message : String,
  window_label? : String = "",
) -> Result[BundledBridgeMessage, Array[String]] {
  self.manifest.prepare_bridge_message(message, window_label~)
}

///|
pub fn BundledRuntimeManifest::bridge_dispatch_task(
  self : BundledRuntimeManifest,
  message : String,
  window_label? : String = "",
) -> Result[BundledBridgeDispatchTask, Array[String]] {
  BundledRuntime::new(self).bridge_dispatch_task(message, window_label~)
}

///|
pub fn BundledRuntime::bridge_dispatch_task(
  self : BundledRuntime,
  message : String,
  window_label? : String = "",
) -> Result[BundledBridgeDispatchTask, Array[String]] {
  match self.prepare_bridge_message(message, window_label~) {
    Err(problems) => Err(problems)
    Ok(prepared) =>
      match @runtime.decode_invoke_request_json(message) {
        Err(problem) => Err([problem])
        Ok(request) => {
          let route = request.route()
          let mode = if self.manifest.registered_async_routes().contains(route) {
            @runtime.NativeBridgeDispatchAsync
          } else {
            NativeBridgeDispatchSync
          }
          Ok({ message: prepared, route, mode })
        }
      }
  }
}

///|
pub fn BundledRuntimeManifest::bridge_response_hook(
  self : BundledRuntimeManifest,
  window_label? : String = "",
) -> Result[(String, String), String] {
  match self.webviews() {
    Err(problem) => Err(problem)
    Ok(webviews) => {
      if window_label != "" {
        for webview in webviews {
          if webview.label() == window_label {
            return Ok((webview.label(), "\{webview.native_hook()}Response"))
          }
        }
        return Err("bundled bridge window not found: \{window_label}")
      }
      match webviews.get(0) {
        Some(webview) =>
          Ok((webview.label(), "\{webview.native_hook()}Response"))
        None => Err("bundled bridge dispatch requires at least one webview")
      }
    }
  }
}

///|
pub fn BundledRuntimeManifest::dispatch_bridge_message_sync(
  self : BundledRuntimeManifest,
  message : String,
  window_label? : String = "",
) -> Result[BundledBridgeDispatch, Array[String]] {
  BundledRuntime::new(self).dispatch_bridge_message_sync(message, window_label~)
}

///|
pub fn BundledRuntime::dispatch_bridge_message_sync(
  self : BundledRuntime,
  message : String,
  window_label? : String = "",
) -> Result[BundledBridgeDispatch, Array[String]] {
  match self.prepare_bridge_message(message, window_label~) {
    Err(problems) => Err(problems)
    Ok(prepared) => Ok(prepared.dispatch_sync(self))
  }
}

///|
pub fn BundledRuntime::dispatch_bridge_script_bytes(
  self : BundledRuntime,
  message : Bytes,
) -> Bytes {
  let input = @utf8.decode(message) catch { _ => "" }
  match self.dispatch_bridge_message_sync(input) {
    Ok(dispatch) => @utf8.encode(dispatch.evaluation_script())
    Err(_) => @utf8.encode("")
  }
}

///|
pub async fn BundledRuntime::dispatch_bridge_script_bytes_async(
  self : BundledRuntime,
  message : Bytes,
) -> Bytes {
  let input = @utf8.decode(message) catch { _ => "" }
  match self.dispatch_bridge_message(input) {
    Ok(dispatch) => @utf8.encode(dispatch.evaluation_script())
    Err(_) => @utf8.encode("")
  }
}

///|
pub async fn BundledRuntimeManifest::dispatch_bridge_message(
  self : BundledRuntimeManifest,
  message : String,
  window_label? : String = "",
) -> Result[BundledBridgeDispatch, Array[String]] {
  BundledRuntime::new(self).dispatch_bridge_message(message, window_label~)
}

///|
pub async fn BundledRuntime::dispatch_bridge_message(
  self : BundledRuntime,
  message : String,
  window_label? : String = "",
) -> Result[BundledBridgeDispatch, Array[String]] {
  match self.prepare_bridge_message(message, window_label~) {
    Err(problems) => Err(problems)
    Ok(prepared) => Ok(prepared.dispatch(self))
  }
}

///|
pub fn BundledBridgeMessage::dispatch_sync(
  self : BundledBridgeMessage,
  runtime : BundledRuntime,
) -> BundledBridgeDispatch {
  let response_json = match @runtime.decode_invoke_request_json(self.message) {
    Ok(request) =>
      runtime.dispatch_json(
        id=request.id(),
        window_label=request.window_label(),
        route=request.route(),
        payload=request.payload(),
      )
    Err(problem) =>
      @runtime.encode_invoke_response_json(
        @lepusa.InvokeResponse::error("", problem),
      )
  }
  self.to_dispatch(response_json)
}

///|
pub async fn BundledBridgeMessage::dispatch(
  self : BundledBridgeMessage,
  runtime : BundledRuntime,
) -> BundledBridgeDispatch {
  let response_json = match @runtime.decode_invoke_request_json(self.message) {
    Ok(request) =>
      runtime.dispatch_json_async(
        id=request.id(),
        window_label=request.window_label(),
        route=request.route(),
        payload=request.payload(),
      )
    Err(problem) =>
      @runtime.encode_invoke_response_json(
        @lepusa.InvokeResponse::error("", problem),
      )
  }
  self.to_dispatch(response_json)
}

///|
fn BundledBridgeMessage::to_dispatch(
  self : BundledBridgeMessage,
  response_json : String,
) -> BundledBridgeDispatch {
  {
    window_label: self.window_label,
    response_hook: self.response_hook,
    message: self.message,
    response_json,
    evaluation_script: @runtime.native_bridge_response_script(
      self.response_hook,
      response_json,
    ),
  }
}

///|
pub fn BundledBridgeMessage::window_label(
  self : BundledBridgeMessage,
) -> String {
  self.window_label
}

///|
pub fn BundledBridgeMessage::response_hook(
  self : BundledBridgeMessage,
) -> String {
  self.response_hook
}

///|
pub fn BundledBridgeMessage::message(self : BundledBridgeMessage) -> String {
  self.message
}

///|
pub fn BundledBridgeDispatchTask::message(
  self : BundledBridgeDispatchTask,
) -> BundledBridgeMessage {
  self.message
}

///|
pub fn BundledBridgeDispatchTask::window_label(
  self : BundledBridgeDispatchTask,
) -> String {
  self.message.window_label()
}

///|
pub fn BundledBridgeDispatchTask::response_hook(
  self : BundledBridgeDispatchTask,
) -> String {
  self.message.response_hook()
}

///|
pub fn BundledBridgeDispatchTask::route(
  self : BundledBridgeDispatchTask,
) -> String {
  self.route
}

///|
pub fn BundledBridgeDispatchTask::mode(
  self : BundledBridgeDispatchTask,
) -> @runtime.NativeBridgeDispatchMode {
  self.mode
}

///|
pub fn BundledBridgeDispatchTask::requires_async_dispatch(
  self : BundledBridgeDispatchTask,
) -> Bool {
  self.mode == NativeBridgeDispatchAsync
}

///|
pub async fn BundledBridgeDispatchTask::dispatch(
  self : BundledBridgeDispatchTask,
  runtime : BundledRuntime,
) -> BundledBridgeDispatch {
  match self.mode {
    NativeBridgeDispatchSync => self.message.dispatch_sync(runtime)
    NativeBridgeDispatchAsync => self.message.dispatch(runtime)
  }
}

///|
pub fn BundledBridgeDispatchTask::to_json(
  self : BundledBridgeDispatchTask,
) -> String {
  [
    "{",
    "\"windowLabel\":\{self.window_label().json_string()},",
    "\"responseHook\":\{self.response_hook().json_string()},",
    "\"route\":\{self.route.json_string()},",
    "\"mode\":\{self.mode.name().json_string()}",
    "}",
  ].join("")
}

///|
pub fn BundledBridgeDispatch::window_label(
  self : BundledBridgeDispatch,
) -> String {
  self.window_label
}

///|
pub fn BundledBridgeDispatch::response_hook(
  self : BundledBridgeDispatch,
) -> String {
  self.response_hook
}

///|
pub fn BundledBridgeDispatch::message(self : BundledBridgeDispatch) -> String {
  self.message
}

///|
pub fn BundledBridgeDispatch::response_json(
  self : BundledBridgeDispatch,
) -> String {
  self.response_json
}

///|
pub fn BundledBridgeDispatch::evaluation_script(
  self : BundledBridgeDispatch,
) -> String {
  self.evaluation_script
}

///|
fn bundled_bridge_window_label_from_message(
  message : String,
  window_label~ : String,
) -> String {
  if window_label != "" {
    window_label
  } else {
    match @runtime.decode_invoke_request_json(message) {
      Ok(request) => request.window_label()
      Err(_) => ""
    }
  }
}
