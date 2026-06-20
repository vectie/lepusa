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
pub(all) enum NativeBridgeDispatchMode {
  NativeBridgeDispatchSync
  NativeBridgeDispatchAsync
} derive(Debug, Eq)

///|
pub struct NativeBridgeDispatchTask {
  message : NativeBridgeMessage
  route : String
  mode : NativeBridgeDispatchMode
} derive(Debug, Eq)

///|
pub fn RuntimeHost::prepare_bridge_message(
  self : RuntimeHost,
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
pub fn RuntimeHost::bridge_dispatch_task(
  self : RuntimeHost,
  message : String,
  window_label? : String = "",
) -> Result[NativeBridgeDispatchTask, Array[String]] {
  match self.prepare_bridge_message(message, window_label~) {
    Err(problems) => Err(problems)
    Ok(prepared) =>
      match decode_invoke_request_json(message) {
        Err(problem) => Err([problem])
        Ok(request) => {
          let route = request.route()
          let mode = if self.async_command_routes().contains(route) {
            NativeBridgeDispatchAsync
          } else {
            NativeBridgeDispatchSync
          }
          Ok({ message: prepared, route, mode })
        }
      }
  }
}

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
pub fn NativeRuntime::bridge_dispatch_task(
  self : NativeRuntime,
  message : String,
  window_label? : String = "",
) -> Result[NativeBridgeDispatchTask, Array[String]] {
  match self.prepare_bridge_message(message, window_label~) {
    Err(problems) => Err(problems)
    Ok(prepared) =>
      match decode_invoke_request_json(message) {
        Err(problem) => Err([problem])
        Ok(request) => {
          let route = request.route()
          let mode = if self.host.async_command_routes().contains(route) {
            NativeBridgeDispatchAsync
          } else {
            NativeBridgeDispatchSync
          }
          Ok({ message: prepared, route, mode })
        }
      }
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
pub fn NativeRuntime::dispatch_bridge_message_sync(
  self : NativeRuntime,
  message : String,
  window_label? : String = "",
) -> Result[NativeBridgeDispatch, Array[String]] {
  match self.prepare_bridge_message(message, window_label~) {
    Err(problems) => Err(problems)
    Ok(prepared) => Ok(prepared.dispatch_sync(self))
  }
}

///|
pub fn NativeRuntime::dispatch_bridge_script_bytes(
  self : NativeRuntime,
  message : Bytes,
) -> Bytes {
  let input = @utf8.decode(message) catch { _ => "" }
  match self.dispatch_bridge_message_sync(input) {
    Ok(dispatch) => @utf8.encode(dispatch.evaluation_script())
    Err(_) => @utf8.encode("")
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
pub fn RuntimeHost::bridge_response_hook(
  self : RuntimeHost,
  window_label? : String = "",
) -> Result[(String, String), String] {
  match self.webviews() {
    Err(problems) => Err(problems.join("; "))
    Ok(specs) => {
      if specs.is_empty() {
        return Err("runtime bridge dispatch requires at least one webview")
      }
      if window_label != "" {
        for spec in specs {
          if spec.label() == window_label {
            return Ok((spec.label(), "\{spec.native_hook()}Response"))
          }
        }
        return Err("runtime bridge window not found: \{window_label}")
      }
      let spec = specs[0]
      Ok((spec.label(), "\{spec.native_hook()}Response"))
    }
  }
}

///|
pub async fn NativeBridgeMessage::dispatch(
  self : NativeBridgeMessage,
  runtime : NativeRuntime,
) -> NativeBridgeDispatch {
  let response_json = runtime.dispatch_json_async(self.message)
  self.to_dispatch(response_json)
}

///|
pub fn NativeBridgeMessage::dispatch_sync(
  self : NativeBridgeMessage,
  runtime : NativeRuntime,
) -> NativeBridgeDispatch {
  let response_json = runtime.dispatch_json(self.message)
  self.to_dispatch(response_json)
}

///|
fn NativeBridgeMessage::to_dispatch(
  self : NativeBridgeMessage,
  response_json : String,
) -> NativeBridgeDispatch {
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
pub fn NativeBridgeDispatchMode::name(
  self : NativeBridgeDispatchMode,
) -> String {
  match self {
    NativeBridgeDispatchSync => "sync"
    NativeBridgeDispatchAsync => "async"
  }
}

///|
pub fn NativeBridgeDispatchTask::message(
  self : NativeBridgeDispatchTask,
) -> NativeBridgeMessage {
  self.message
}

///|
pub fn NativeBridgeDispatchTask::window_label(
  self : NativeBridgeDispatchTask,
) -> String {
  self.message.window_label()
}

///|
pub fn NativeBridgeDispatchTask::response_hook(
  self : NativeBridgeDispatchTask,
) -> String {
  self.message.response_hook()
}

///|
pub fn NativeBridgeDispatchTask::route(
  self : NativeBridgeDispatchTask,
) -> String {
  self.route
}

///|
pub fn NativeBridgeDispatchTask::mode(
  self : NativeBridgeDispatchTask,
) -> NativeBridgeDispatchMode {
  self.mode
}

///|
pub fn NativeBridgeDispatchTask::requires_async_dispatch(
  self : NativeBridgeDispatchTask,
) -> Bool {
  self.mode == NativeBridgeDispatchAsync
}

///|
pub async fn NativeBridgeDispatchTask::dispatch(
  self : NativeBridgeDispatchTask,
  runtime : NativeRuntime,
) -> NativeBridgeDispatch {
  match self.mode {
    NativeBridgeDispatchSync => self.message.dispatch_sync(runtime)
    NativeBridgeDispatchAsync => self.message.dispatch(runtime)
  }
}

///|
pub fn NativeBridgeDispatchTask::to_json(
  self : NativeBridgeDispatchTask,
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
pub fn native_webkit_bridge_hook_script(
  hook : String,
  platform_name~ : String,
) -> String {
  native_bridge_hook_script(hook, post_message_lines=[
    "      const handler = globalThis.webkit && globalThis.webkit.messageHandlers && globalThis.webkit.messageHandlers[nativeHook];",
    "      if (!handler || typeof handler.postMessage !== \"function\") {",
    "        reject(new Error(`\{missing_bridge_message("Missing Lepusa \{platform_name} native message handler")}: ${nativeHook}`));",
    "        return;",
    "      }",
    "      pending.set(String(request.id || \"\"), { resolve, reject });",
    "      handler.postMessage(JSON.stringify(request));",
  ])
}

///|
pub fn native_webview2_bridge_hook_script(hook : String) -> String {
  native_bridge_hook_script(hook, post_message_lines=[
    "      const chrome = globalThis.chrome;",
    "      const webview = chrome && chrome.webview;",
    "      if (!webview || typeof webview.postMessage !== \"function\") {",
    "        reject(new Error(`\{missing_bridge_message("Missing Lepusa Windows WebView2 bridge")}: ${nativeHook}`));",
    "        return;",
    "      }",
    "      pending.set(String(request.id || \"\"), { resolve, reject });",
    "      webview.postMessage(JSON.stringify({ hook: nativeHook, request }));",
  ])
}

///|
fn native_bridge_hook_script(
  hook : String,
  post_message_lines~ : Array[String],
) -> String {
  let native_hook = hook.js_string_literal()
  let response_hook = "\{hook}Response".js_string_literal()
  let lines = [
    "(() => {",
    "  const nativeHook = \{native_hook};",
    "  const responseHook = \{response_hook};",
    "  const pending = new Map();",
    "  Object.defineProperty(globalThis, responseHook, {",
    "    value: (response) => {",
    "      const id = response && String(response.id || \"\");",
    "      const callbacks = pending.get(id);",
    "      if (!callbacks) { return false; }",
    "      pending.delete(id);",
    "      if (response && response.error) { callbacks.reject(new Error(response.error)); }",
    "      else { callbacks.resolve(response || null); }",
    "      return true;",
    "    },",
    "    configurable: true,",
    "  });",
    "  Object.defineProperty(globalThis, nativeHook, {",
    "    value: (request) => new Promise((resolve, reject) => {",
  ]
  for line in post_message_lines {
    lines.push(line)
  }
  for line in ["    }),", "    configurable: true,", "  });", "})();"] {
    lines.push(line)
  }
  lines.join("\n")
}

///|
fn missing_bridge_message(message : String) -> String {
  message.replace_all(old="`", new="'")
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
