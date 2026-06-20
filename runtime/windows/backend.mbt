///|
extern "c" fn backend_available() -> Int = "lepusa_windows_backend_available"

///|
extern "c" fn backend_engine_name() -> Bytes = "lepusa_windows_backend_engine_name"

///|
pub struct WindowsPreflight {
  webview2_loader : Bool
  webview_creation_loop : Bool
} derive(Debug, Eq)

///|
pub fn backend() -> @runtime.NativeBackend {
  @runtime.NativeBackend::new(
    name="windows",
    webview_engine=@utf8.decode_lossy(backend_engine_name()),
  )
}

///|
pub fn available() -> Bool {
  backend_available() == 1
}

///|
pub fn detect() -> Result[@runtime.NativeBackend, String] {
  if available() {
    Ok(backend())
  } else {
    Err("Windows WebView2 backend is not available")
  }
}

///|
pub fn launch_capability() -> @runtime.NativeLaunchCapability {
  let preflight = preflight()
  @runtime.NativeLaunchCapability::new(
    webview_creation=preflight.webview_creation_loop(),
    async_bridge_drain=false,
    webview_creation_message=preflight.problem(),
  )
}

///|
pub fn preflight() -> WindowsPreflight {
  { webview2_loader: available(), webview_creation_loop: false }
}

///|
pub fn WindowsPreflight::webview2_loader(self : WindowsPreflight) -> Bool {
  self.webview2_loader
}

///|
pub fn WindowsPreflight::webview_creation_loop(self : WindowsPreflight) -> Bool {
  self.webview_creation_loop
}

///|
pub fn WindowsPreflight::can_launch(self : WindowsPreflight) -> Bool {
  self.webview2_loader && self.webview_creation_loop
}

///|
pub fn WindowsPreflight::problem(self : WindowsPreflight) -> String {
  if !self.webview2_loader {
    "Windows WebView2 loader is not available"
  } else if !self.webview_creation_loop {
    "Windows WebView2 creation loop is unavailable"
  } else {
    ""
  }
}

///|
pub fn WindowsPreflight::to_json(self : WindowsPreflight) -> String {
  [
    "{",
    "\"webview2Loader\":\{self.webview2_loader.to_string()},",
    "\"webviewCreationLoop\":\{self.webview_creation_loop.to_string()},",
    "\"canLaunch\":\{self.can_launch().to_string()},",
    "\"problem\":\{windows_json_string(self.problem())}",
    "}",
  ].join("")
}

///|
fn windows_json_string(value : String) -> String {
  let out = ["\""]
  for ch in value {
    match ch {
      '"' => out.push("\\\"")
      '\\' => out.push("\\\\")
      '\n' => out.push("\\n")
      '\r' => out.push("\\r")
      '\t' => out.push("\\t")
      _ => out.push(ch.to_string())
    }
  }
  out.push("\"")
  out.join("")
}

///|
pub fn runtime(
  host : @runtime.RuntimeHost,
) -> Result[@runtime.NativeRuntime, Array[String]] {
  @runtime.NativeRuntime::new(backend(), host)
}

///|
pub fn detect_runtime(
  host : @runtime.RuntimeHost,
) -> Result[@runtime.NativeRuntime, Array[String]] {
  match detect() {
    Ok(backend) => @runtime.NativeRuntime::new(backend, host)
    Err(problem) => Err([problem])
  }
}
