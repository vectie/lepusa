///|
pub struct NativeBridgeMessage {
  window_label : String
  response_hook : String
  message : String
} derive(Debug, Eq)

///|
pub struct NativeBridgeDispatch {
  window_label : String
  response_hook : String
  message : String
  response_json : String
  evaluation_script : String
} derive(Debug, Eq)

///|
pub fn NativeRuntime::prepare_bridge_message(
  self : NativeRuntime,
  message : String,
  window_label? : String = "",
) -> Result[NativeBridgeMessage, Array[String]] {
  let resolved_window_label = bridge_window_label_from_message(
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
pub async fn NativeRuntime::dispatch_bridge_message(
  self : NativeRuntime,
  message : String,
  window_label? : String = "",
) -> Result[NativeBridgeDispatch, Array[String]] {
  match self.prepare_bridge_message(message, window_label~) {
    Err(problems) => Err(problems)
    Ok(prepared) => Ok(prepared.dispatch(self))
  }
}

///|
pub fn NativeRuntime::bridge_response_hook(
  self : NativeRuntime,
  window_label? : String = "",
) -> Result[(String, String), String] {
  let specs = self.runner.webview_specs()
  if specs.is_empty() {
    return Err("native bridge dispatch requires at least one webview")
  }
  if window_label != "" {
    for spec in specs {
      if spec.label() == window_label {
        return Ok((spec.label(), "\{spec.native_hook()}Response"))
      }
    }
    return Err("native bridge window not found: \{window_label}")
  }
  let spec = specs[0]
  Ok((spec.label(), "\{spec.native_hook()}Response"))
}

///|
pub async fn NativeBridgeMessage::dispatch(
  self : NativeBridgeMessage,
  runtime : NativeRuntime,
) -> NativeBridgeDispatch {
  let response_json = runtime.dispatch_json_async(self.message)
  {
    window_label: self.window_label,
    response_hook: self.response_hook,
    message: self.message,
    response_json,
    evaluation_script: native_bridge_response_script(
      self.response_hook,
      response_json,
    ),
  }
}

///|
pub fn NativeBridgeMessage::window_label(self : NativeBridgeMessage) -> String {
  self.window_label
}

///|
pub fn NativeBridgeMessage::response_hook(self : NativeBridgeMessage) -> String {
  self.response_hook
}

///|
pub fn NativeBridgeMessage::message(self : NativeBridgeMessage) -> String {
  self.message
}

///|
pub fn NativeBridgeDispatch::window_label(
  self : NativeBridgeDispatch,
) -> String {
  self.window_label
}

///|
pub fn NativeBridgeDispatch::response_hook(
  self : NativeBridgeDispatch,
) -> String {
  self.response_hook
}

///|
pub fn NativeBridgeDispatch::message(self : NativeBridgeDispatch) -> String {
  self.message
}

///|
pub fn NativeBridgeDispatch::response_json(
  self : NativeBridgeDispatch,
) -> String {
  self.response_json
}

///|
pub fn NativeBridgeDispatch::evaluation_script(
  self : NativeBridgeDispatch,
) -> String {
  self.evaluation_script
}

///|
pub fn native_bridge_response_script(
  response_hook : String,
  response_json : String,
) -> String {
  "globalThis[\{response_hook.js_string_literal()}](\{response_json});"
}

///|
fn bridge_window_label_from_message(
  message : String,
  window_label~ : String,
) -> String {
  if window_label != "" {
    window_label
  } else {
    match decode_invoke_request_json(message) {
      Ok(request) => request.window_label()
      Err(_) => ""
    }
  }
}

///|
fn String::js_string_literal(self : String) -> String {
  "\"" +
  self
  .replace_all(old="\\", new="\\\\")
  .replace_all(old="\"", new="\\\"")
  .replace_all(old="\n", new="\\n")
  .replace_all(old="\r", new="\\r")
  .replace_all(old="\t", new="\\t") +
  "\""
}
