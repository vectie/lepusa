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
pub fn MacOSBackend::runner_plan(
  self : MacOSBackend,
  host : @runtime.RuntimeHost,
) -> Result[MacOSRunnerPlan, Array[String]] {
  let startup_operations : Array[MacOSOperation] = []
  match host.runner_plan() {
    Ok(plan) => {
      for operation in plan.startup_operations() {
        startup_operations.push(MacOSOperation::from_runtime(operation))
      }
      Ok({
        backend_name: self.name,
        webview_engine: self.webview_engine,
        launch_plan: {
          backend_name: self.name,
          webview_engine: self.webview_engine,
          manifest: plan.launch_manifest(),
        },
        session: plan.session(),
        startup_operations,
      })
    }
    Err(problems) => Err(problems)
  }
}

///|
pub struct MacOSLaunchPlan {
  backend_name : String
  webview_engine : String
  manifest : @lepusa.RuntimeLaunchManifest
} derive(Debug, Eq)

///|
pub(all) enum MacOSOperation {
  MacOSSendEvent(@lepusa.EventTarget, @lepusa.Event)
  MacOSRunEffect(String)
  MacOSNavigateWindow(String, String)
} derive(Debug, Eq)

///|
pub struct MacOSRunnerPlan {
  backend_name : String
  webview_engine : String
  launch_plan : MacOSLaunchPlan
  session : @runtime.RuntimeSession
  startup_operations : Array[MacOSOperation]
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
) -> Array[@lepusa.RuntimeWebViewBoot] {
  self.manifest.webviews()
}

///|
pub fn MacOSLaunchPlan::runtime_manifest(
  self : MacOSLaunchPlan,
) -> @lepusa.RuntimeLaunchManifest {
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
pub fn MacOSOperation::from_runtime(
  operation : @runtime.RuntimeOperation,
) -> MacOSOperation {
  match operation {
    RuntimeSendEvent(target, event) => MacOSSendEvent(target, event)
    RuntimeRunEffect(name) => MacOSRunEffect(name)
    RuntimeNavigateWindow(label, url) => MacOSNavigateWindow(label, url)
  }
}

///|
pub fn MacOSOperation::to_json(self : MacOSOperation) -> String {
  match self {
    MacOSSendEvent(target, event) =>
      [
        "{",
        "\"kind\":\"send-event\",",
        "\"target\":\{target.to_json()},",
        "\"event\":\{event.to_json()}",
        "}",
      ].join("")
    MacOSRunEffect(name) =>
      ["{", "\"kind\":\"run-effect\",", "\"name\":\{name.json_string()}", "}"].join(
        "",
      )
    MacOSNavigateWindow(label, url) =>
      [
        "{",
        "\"kind\":\"navigate-window\",",
        "\"label\":\{label.json_string()},",
        "\"url\":\{url.json_string()}",
        "}",
      ].join("")
  }
}

///|
pub fn MacOSRunnerPlan::backend_name(self : MacOSRunnerPlan) -> String {
  self.backend_name
}

///|
pub fn MacOSRunnerPlan::webview_engine(self : MacOSRunnerPlan) -> String {
  self.webview_engine
}

///|
pub fn MacOSRunnerPlan::launch_plan(self : MacOSRunnerPlan) -> MacOSLaunchPlan {
  self.launch_plan
}

///|
pub fn MacOSRunnerPlan::session(
  self : MacOSRunnerPlan,
) -> @runtime.RuntimeSession {
  self.session
}

///|
pub fn MacOSRunnerPlan::startup_operations(
  self : MacOSRunnerPlan,
) -> Array[MacOSOperation] {
  self.startup_operations.copy()
}

///|
pub fn MacOSRunnerPlan::webviews(
  self : MacOSRunnerPlan,
) -> Array[@lepusa.RuntimeWebViewBoot] {
  self.launch_plan.webviews()
}

///|
pub fn MacOSRunnerPlan::bootstrap_json(self : MacOSRunnerPlan) -> String {
  [
    "{",
    "\"nativeBackend\":\{self.backend_name.json_string()},",
    "\"webviewEngine\":\{self.webview_engine.json_string()},",
    "\"runtime\":\{self.launch_plan.runtime_manifest().to_json()},",
    "\"startupOperations\":[\{self.startup_operations.map(fn(operation) { operation.to_json() }).join(",")}]",
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
