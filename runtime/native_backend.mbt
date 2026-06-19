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
  NativeDispatchEvent(@lepusa.FrontendEventDispatch)
  NativeRunEffect(String)
  NativeNavigateWindow(String, String)
} derive(Debug, Eq)

///|
pub struct NativeRunnerPlan {
  backend_name : String
  webview_engine : String
  launch_plan : NativeLaunchPlan
  session : RuntimeSession
  webview_specs : Array[RuntimeWebViewSpec]
  startup_operations : Array[NativeOperation]
  lifecycle_steps : Array[NativeRunnerStep]
} derive(Debug, Eq)

///|
pub struct NativeRunnerStep {
  event : @lepusa.LifecycleEvent
  session : RuntimeSession
  operations : Array[NativeOperation]
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
  match host.runner_plan() {
    Ok(plan) =>
      Ok({
        backend_name: self.name,
        webview_engine: self.webview_engine,
        launch_plan: {
          backend_name: self.name,
          webview_engine: self.webview_engine,
          manifest: plan.launch_manifest(),
        },
        session: plan.session(),
        webview_specs: plan.webviews(),
        startup_operations: native_operations_from_runtime(
          plan.startup_operations(),
        ),
        lifecycle_steps: native_lifecycle_steps_from_runtime(
          plan.lifecycle_steps(),
        ),
      })
    Err(problems) => Err(problems)
  }
}

///|
pub fn NativeBackend::service_executor(
  self : NativeBackend,
  start_service~ : NativeServiceActionHandler,
  wait_until_ready~ : NativeServiceActionHandler,
  stop_service~ : NativeServiceActionHandler,
) -> NativeServiceExecutor {
  NativeServiceExecutor::new(
    backend_name=self.name,
    webview_engine=self.webview_engine,
    start_service~,
    wait_until_ready~,
    stop_service~,
  )
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
    RuntimeDispatchEvent(dispatch) => NativeDispatchEvent(dispatch)
    RuntimeRunEffect(name) => NativeRunEffect(name)
    RuntimeNavigateWindow(label, url) => NativeNavigateWindow(label, url)
  }
}

///|
fn native_operations_from_runtime(
  operations : Array[RuntimeOperation],
) -> Array[NativeOperation] {
  let native : Array[NativeOperation] = []
  for operation in operations {
    native.push(NativeOperation::from_runtime(operation))
  }
  native
}

///|
fn native_lifecycle_steps_from_runtime(
  steps : Array[RuntimeRunnerStep],
) -> Array[NativeRunnerStep] {
  let native : Array[NativeRunnerStep] = []
  for step in steps {
    native.push({
      event: step.event(),
      session: step.session(),
      operations: native_operations_from_runtime(step.operations()),
    })
  }
  native
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
    NativeDispatchEvent(dispatch) =>
      [
        "{",
        "\"kind\":\"dispatch-event\",",
        "\"dispatch\":\{dispatch.to_json()}",
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
pub fn NativeRunnerPlan::lifecycle_steps(
  self : NativeRunnerPlan,
) -> Array[NativeRunnerStep] {
  self.lifecycle_steps.copy()
}

///|
pub fn NativeRunnerPlan::webview_specs(
  self : NativeRunnerPlan,
) -> Array[RuntimeWebViewSpec] {
  self.webview_specs.copy()
}

///|
pub fn NativeRunnerPlan::webviews(
  self : NativeRunnerPlan,
) -> Array[@lepusa.RuntimeWebViewBoot] {
  self.launch_plan.webviews()
}

///|
pub fn NativeRunnerPlan::lifecycle_step(
  self : NativeRunnerPlan,
  event : @lepusa.LifecycleEvent,
) -> Result[NativeRunnerStep, Array[String]] {
  for step in self.lifecycle_steps {
    if step.event() == event {
      return Ok(step)
    }
  }
  match event {
    AppStarted =>
      match self.session.lifecycle_step(event) {
        Ok(step) =>
          Ok({
            event,
            session: step.session(),
            operations: native_operations_from_runtime(step.operations()),
          })
        Err(problems) => Err(problems)
      }
    _ => Ok({ event, session: self.session, operations: [] })
  }
}

///|
pub fn NativeRunnerPlan::bootstrap_json(self : NativeRunnerPlan) -> String {
  [
    "{",
    "\"nativeBackend\":\{self.backend_name.json_string()},",
    "\"webviewEngine\":\{self.webview_engine.json_string()},",
    "\"runtime\":\{self.launch_plan.runtime_manifest().to_json()},",
    "\"webviewSpecs\":[\{self.webview_specs.map(fn(spec) { spec.to_json() }).join(",")}],",
    "\"serviceSupervisor\":\{self.service_supervisor_plan().to_json()},",
    "\"startupOperations\":[\{self.startup_operations.map(fn(operation) { operation.to_json() }).join(",")}],",
    "\"lifecycleOperations\":[\{self.lifecycle_steps.map(fn(step) { step.to_json() }).join(",")}]",
    "}",
  ].join("")
}

///|
pub fn NativeRunnerStep::event(
  self : NativeRunnerStep,
) -> @lepusa.LifecycleEvent {
  self.event
}

///|
pub fn NativeRunnerStep::session(self : NativeRunnerStep) -> RuntimeSession {
  self.session
}

///|
pub fn NativeRunnerStep::operations(
  self : NativeRunnerStep,
) -> Array[NativeOperation] {
  self.operations.copy()
}

///|
pub fn NativeRunnerStep::to_json(self : NativeRunnerStep) -> String {
  [
    "{",
    "\"event\":\{self.event.to_json()},",
    "\"operations\":[\{self.operations.map(fn(operation) { operation.to_json() }).join(",")}],",
    "\"session\":\{self.session.to_json()}",
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

///|
fn Bool::json_bool(self : Bool) -> String {
  if self {
    "true"
  } else {
    "false"
  }
}

///|
fn @lepusa.TitleBarStyle::native_manifest_name(
  self : @lepusa.TitleBarStyle,
) -> String {
  match self {
    Native => "native"
    Transparent => "transparent"
    Hidden => "hidden"
  }
}
