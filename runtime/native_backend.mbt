///|
pub struct NativeBackend {
  name : String
  webview_engine : String
} derive(Debug, Eq)

///|
pub struct NativeLaunchPlan {
  backend_name : String
  webview_engine : String
  manifest : @lepusa.RuntimeLaunchManifest
} derive(Debug, Eq)

///|
pub(all) enum NativeOperation {
  NativeStartService(@lepusa.LocalService)
  NativeSendEvent(@lepusa.EventTarget, @lepusa.Event)
  NativeRunEffect(String)
  NativeNavigateWindow(String, String)
} derive(Debug, Eq)

///|
pub struct NativeRunnerPlan {
  backend_name : String
  webview_engine : String
  launch_plan : NativeLaunchPlan
  session : RuntimeSession
  startup_operations : Array[NativeOperation]
} derive(Debug, Eq)

///|
pub fn NativeBackend::new(
  name~ : String,
  webview_engine~ : String,
) -> NativeBackend {
  { name, webview_engine }
}

///|
pub fn NativeBackend::name(self : NativeBackend) -> String {
  self.name
}

///|
pub fn NativeBackend::webview_engine(self : NativeBackend) -> String {
  self.webview_engine
}

///|
pub fn NativeBackend::plan(
  self : NativeBackend,
  host : RuntimeHost,
) -> Result[NativeLaunchPlan, Array[String]] {
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
pub fn NativeBackend::runner_plan(
  self : NativeBackend,
  host : RuntimeHost,
) -> Result[NativeRunnerPlan, Array[String]] {
  let startup_operations : Array[NativeOperation] = []
  match host.runner_plan() {
    Ok(plan) => {
      for operation in plan.startup_operations() {
        startup_operations.push(NativeOperation::from_runtime(operation))
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
pub fn NativeLaunchPlan::backend_name(self : NativeLaunchPlan) -> String {
  self.backend_name
}

///|
pub fn NativeLaunchPlan::webview_engine(self : NativeLaunchPlan) -> String {
  self.webview_engine
}

///|
pub fn NativeLaunchPlan::webviews(
  self : NativeLaunchPlan,
) -> Array[@lepusa.RuntimeWebViewBoot] {
  self.manifest.webviews()
}

///|
pub fn NativeLaunchPlan::runtime_manifest(
  self : NativeLaunchPlan,
) -> @lepusa.RuntimeLaunchManifest {
  self.manifest
}

///|
pub fn NativeLaunchPlan::manifest_json(self : NativeLaunchPlan) -> String {
  [
    "{",
    "\"nativeBackend\":\{self.backend_name.json_string()},",
    "\"webviewEngine\":\{self.webview_engine.json_string()},",
    "\"runtime\":\{self.manifest.to_json()}",
    "}",
  ].join("")
}

///|
pub fn NativeOperation::from_runtime(
  operation : RuntimeOperation,
) -> NativeOperation {
  match operation {
    RuntimeStartService(service) => NativeStartService(service)
    RuntimeSendEvent(target, event) => NativeSendEvent(target, event)
    RuntimeRunEffect(name) => NativeRunEffect(name)
    RuntimeNavigateWindow(label, url) => NativeNavigateWindow(label, url)
  }
}

///|
pub fn NativeOperation::to_json(self : NativeOperation) -> String {
  match self {
    NativeStartService(service) =>
      [
        "{",
        "\"kind\":\"start-service\",",
        "\"service\":\{service.to_json()}",
        "}",
      ].join("")
    NativeSendEvent(target, event) =>
      [
        "{",
        "\"kind\":\"send-event\",",
        "\"target\":\{target.to_json()},",
        "\"event\":\{event.to_json()}",
        "}",
      ].join("")
    NativeRunEffect(name) =>
      ["{", "\"kind\":\"run-effect\",", "\"name\":\{name.json_string()}", "}"].join(
        "",
      )
    NativeNavigateWindow(label, url) =>
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
pub fn NativeRunnerPlan::backend_name(self : NativeRunnerPlan) -> String {
  self.backend_name
}

///|
pub fn NativeRunnerPlan::webview_engine(self : NativeRunnerPlan) -> String {
  self.webview_engine
}

///|
pub fn NativeRunnerPlan::launch_plan(
  self : NativeRunnerPlan,
) -> NativeLaunchPlan {
  self.launch_plan
}

///|
pub fn NativeRunnerPlan::session(self : NativeRunnerPlan) -> RuntimeSession {
  self.session
}

///|
pub fn NativeRunnerPlan::startup_operations(
  self : NativeRunnerPlan,
) -> Array[NativeOperation] {
  self.startup_operations.copy()
}

///|
pub fn NativeRunnerPlan::webviews(
  self : NativeRunnerPlan,
) -> Array[@lepusa.RuntimeWebViewBoot] {
  self.launch_plan.webviews()
}

///|
pub fn NativeRunnerPlan::bootstrap_json(self : NativeRunnerPlan) -> String {
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
