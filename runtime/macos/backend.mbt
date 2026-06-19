///|
pub struct MacOSBackend {
  name : String
  webview_engine : String
} derive(Debug, Eq)

///|
extern "c" fn backend_available() -> Int = "lepusa_macos_backend_available"

///|
extern "c" fn backend_engine_name() -> Bytes = "lepusa_macos_backend_engine_name"

///|
pub fn MacOSBackend::new() -> Result[MacOSBackend, String] {
  if backend_available() == 1 {
    Ok({
      name: "macos",
      webview_engine: @utf8.decode_lossy(backend_engine_name()),
    })
  } else {
    Err("macOS Cocoa/WebKit backend is not available")
  }
}

///|
pub fn MacOSBackend::name(self : MacOSBackend) -> String {
  self.name
}

///|
pub fn MacOSBackend::webview_engine(self : MacOSBackend) -> String {
  self.webview_engine
}

///|
pub fn MacOSBackend::plan(
  self : MacOSBackend,
  host : @runtime.RuntimeHost,
) -> Result[MacOSLaunchPlan, Array[String]] {
  match host.launch_manifest() {
    Ok(manifest) =>
      Ok({
        backend_name: self.name,
        webview_engine: self.webview_engine,
        manifest,
      })
    Err(problems) => Err(problems)
  }
}

///|
pub struct MacOSLaunchPlan {
  backend_name : String
  webview_engine : String
  manifest : @runtime.RuntimeLaunchManifest
} derive(Debug, Eq)

///|
pub fn MacOSLaunchPlan::backend_name(self : MacOSLaunchPlan) -> String {
  self.backend_name
}

///|
pub fn MacOSLaunchPlan::webview_engine(self : MacOSLaunchPlan) -> String {
  self.webview_engine
}

///|
pub fn MacOSLaunchPlan::webviews(
  self : MacOSLaunchPlan,
) -> Array[@runtime.RuntimeWebViewSpec] {
  self.manifest.webviews()
}

///|
pub fn MacOSLaunchPlan::runtime_manifest(
  self : MacOSLaunchPlan,
) -> @runtime.RuntimeLaunchManifest {
  self.manifest
}

///|
pub fn MacOSLaunchPlan::manifest_json(self : MacOSLaunchPlan) -> String {
  [
    "{",
    "\"nativeBackend\":\{self.backend_name.json_string()},",
    "\"webviewEngine\":\{self.webview_engine.json_string()},",
    "\"runtime\":\{self.manifest.to_json()}",
    "}",
  ].join("")
}

///|
fn String::json_string(self : String) -> String {
  "\"" +
  self
  .replace_all(old="\\", new="\\\\")
  .replace_all(old="\"", new="\\\"")
  .replace_all(old="\n", new="\\n")
  .replace_all(old="\r", new="\\r")
  .replace_all(old="\t", new="\\t") +
  "\""
}
