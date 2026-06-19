///|
pub struct MacOSBridgeDispatch {
  window_label : String
  response_hook : String
  message : String
  response_json : String
  evaluation_script : String
} derive(Debug, Eq)

///|
pub async fn dispatch_bridge_message(
  runtime : @runtime.NativeRuntime,
  message : String,
  window_label? : String = "",
) -> Result[MacOSBridgeDispatch, Array[String]] {
  let resolved_window_label = resolve_bridge_window_label(
    message,
    window_label~,
  )
  match response_hook_for_window(runtime, resolved_window_label) {
    Err(problem) => Err([problem])
    Ok((window_label, response_hook)) => {
      let response_json = runtime.dispatch_json_async(message)
      Ok({
        window_label,
        response_hook,
        message,
        response_json,
        evaluation_script: bridge_response_script(response_hook, response_json),
      })
    }
  }
}

///|
pub fn MacOSBridgeDispatch::window_label(self : MacOSBridgeDispatch) -> String {
  self.window_label
}

///|
pub fn MacOSBridgeDispatch::response_hook(self : MacOSBridgeDispatch) -> String {
  self.response_hook
}

///|
pub fn MacOSBridgeDispatch::message(self : MacOSBridgeDispatch) -> String {
  self.message
}

///|
pub fn MacOSBridgeDispatch::response_json(self : MacOSBridgeDispatch) -> String {
  self.response_json
}

///|
pub fn MacOSBridgeDispatch::evaluation_script(
  self : MacOSBridgeDispatch,
) -> String {
  self.evaluation_script
}

///|
fn resolve_bridge_window_label(
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

///|
fn response_hook_for_window(
  runtime : @runtime.NativeRuntime,
  window_label : String,
) -> Result[(String, String), String] {
  let specs = runtime.runner_plan().webview_specs()
  if specs.is_empty() {
    return Err("macOS bridge dispatch requires at least one webview")
  }
  if window_label != "" {
    for spec in specs {
      if spec.label() == window_label {
        return Ok((spec.label(), "\{spec.native_hook()}Response"))
      }
    }
    return Err("macOS bridge window not found: \{window_label}")
  }
  let spec = specs[0]
  Ok((spec.label(), "\{spec.native_hook()}Response"))
}

///|
fn bridge_response_script(
  response_hook : String,
  response_json : String,
) -> String {
  "globalThis[\{response_hook.js_string_literal()}](\{response_json});"
}
