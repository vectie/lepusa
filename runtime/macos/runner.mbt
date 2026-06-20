///|
pub(all) enum MacOSRunMode {
  MacOSDryRun
  MacOSOpenWindow
} derive(Debug, Eq)

///|
pub struct MacOSExecutionPlan {
  startup_operations : Array[String]
  lifecycle_steps : Array[MacOSLifecycleStepPlan]
} derive(Debug, Eq)

///|
pub struct MacOSLifecycleStepPlan {
  event_json : String
  operations : Array[String]
} derive(Debug, Eq)

///|
pub struct MacOSBridgePlan {
  sync_command_routes : Array[String]
  async_command_routes : Array[String]
} derive(Debug, Eq)

///|
pub struct MacOSRunPlan {
  webviews : Array[@runtime.NativeWebViewPlan]
  execution : MacOSExecutionPlan
  bridge : MacOSBridgePlan
  service_supervisor : @runtime.NativeServiceSupervisorPlan
} derive(Debug, Eq)

///|
pub struct MacOSRunResult {
  plan : MacOSRunPlan
  status : @lepusa.RunStatus
} derive(Debug, Eq)

///|
#borrow(title, url, initialization_script, native_hook, asset_protocol, dispatch, resolve_asset)
extern "c" fn run_webview_with_bridge(
  title : Bytes,
  url : Bytes,
  initialization_script : Bytes,
  native_hook : Bytes,
  asset_protocol : Bytes,
  width : Int,
  height : Int,
  resizable : Int,
  call_dispatch : FuncRef[((Bytes) -> Bytes, Bytes) -> Bytes],
  dispatch : (Bytes) -> Bytes,
  call_resolve_asset : FuncRef[((Bytes) -> Bytes, Bytes) -> Bytes],
  resolve_asset : (Bytes) -> Bytes,
) -> Int = "lepusa_macos_run_webview_with_bridge"

///|
pub fn prepare_run(
  runtime : @runtime.NativeRuntime,
) -> Result[MacOSRunPlan, Array[String]] {
  match
    runtime.prepare_run_plan(
      prepare_webview=fn(spec) { macos_webview_plan_from_spec(runtime, spec) },
      missing_webview_message="macOS run requires at least one webview",
    ) {
    Ok(plan) => Ok(macos_run_plan_from_prepared(runtime, plan))
    Err(problems) => Err(problems)
  }
}

///|
fn macos_webview_plan_from_spec(
  runtime : @runtime.NativeRuntime,
  spec : @runtime.RuntimeWebViewSpec,
) -> Result[@runtime.NativeWebViewPlan, String] {
  runtime.webview_plan(
    spec,
    initialization_script=macos_initialization_script(
      spec.native_hook(),
      spec.initialization_scripts(),
    ),
  )
}

///|
pub fn prepare_bundled_run(
  manifest : @bundled.BundledRuntimeManifest,
) -> Result[MacOSRunPlan, Array[String]] {
  match
    manifest.prepare_native_run_plan(
      target="macos",
      target_name="macOS",
      prepare_webview=fn(webview) {
        macos_webview_plan_from_bundled(manifest, webview)
      },
      missing_webview_message="macOS bundled run requires at least one webview",
    ) {
    Err(problems) => Err(problems)
    Ok(plan) =>
      match
        macos_execution_plan_from_bundled(manifest, plan.bundled_webviews()) {
        Ok(execution) =>
          Ok({
            webviews: plan.webviews(),
            execution,
            bridge: macos_bridge_plan_from_bundled(manifest),
            service_supervisor: plan.service_supervisor_plan(),
          })
        Err(problems) => Err(problems)
      }
  }
}

///|
fn macos_webview_plan_from_bundled(
  manifest : @bundled.BundledRuntimeManifest,
  webview : @bundled.BundledWebView,
) -> Result[@runtime.NativeWebViewPlan, String] {
  manifest.webview_plan(
    webview,
    initialization_script=macos_initialization_script(
      webview.native_hook(),
      webview.initialization_scripts(),
    ),
  )
}

///|
fn macos_run_plan_from_prepared(
  runtime : @runtime.NativeRuntime,
  plan : @runtime.NativePreparedRunPlan,
) -> MacOSRunPlan {
  {
    webviews: plan.webviews(),
    execution: macos_execution_plan_from_runner(plan.runner()),
    bridge: macos_bridge_plan_from_runtime(runtime),
    service_supervisor: plan.service_supervisor_plan(),
  }
}

///|
fn macos_execution_plan_from_runner(
  runner : @runtime.NativeRunnerPlan,
) -> MacOSExecutionPlan {
  {
    startup_operations: runner
    .startup_operations()
    .map(fn(operation) { operation.to_json() }),
    lifecycle_steps: runner
    .lifecycle_steps()
    .map(fn(step) {
      {
        event_json: step.event().to_json(),
        operations: step.operations().map(fn(operation) { operation.to_json() }),
      }
    }),
  }
}

///|
fn macos_execution_plan_from_bundled(
  manifest : @bundled.BundledRuntimeManifest,
  webviews : Array[@bundled.BundledWebView],
) -> Result[MacOSExecutionPlan, Array[String]] {
  let startup_operations : Array[String] = []
  let problems : Array[String] = []
  for service in manifest.local_service_jsons() {
    startup_operations.push(macos_start_service_operation_json(service))
  }
  for action in manifest.startup_action_jsons() {
    match macos_operation_jsons_from_runtime_action_json(action, webviews) {
      Ok(operations) =>
        for operation in operations {
          startup_operations.push(operation)
        }
      Err(problem) => problems.push(problem)
    }
  }
  let lifecycle_steps : Array[MacOSLifecycleStepPlan] = []
  match manifest.lifecycle_plans() {
    Ok(plans) =>
      for plan in plans {
        let operations : Array[String] = []
        for action in plan.action_jsons() {
          match
            macos_operation_jsons_from_runtime_action_json(action, webviews) {
            Ok(action_operations) =>
              for operation in action_operations {
                operations.push(operation)
              }
            Err(problem) => problems.push(problem)
          }
        }
        lifecycle_steps.push({
          event_json: macos_bundled_lifecycle_event_json(plan.event()),
          operations,
        })
      }
    Err(problem) => problems.push(problem)
  }
  if problems.is_empty() {
    Ok({ startup_operations, lifecycle_steps })
  } else {
    Err(problems)
  }
}

///|
fn macos_bridge_plan_from_runtime(
  runtime : @runtime.NativeRuntime,
) -> MacOSBridgePlan {
  {
    sync_command_routes: runtime.host().sync_command_routes(),
    async_command_routes: runtime.host().async_command_routes(),
  }
}

///|
fn macos_bridge_plan_from_bundled(
  manifest : @bundled.BundledRuntimeManifest,
) -> MacOSBridgePlan {
  {
    sync_command_routes: manifest.registered_sync_routes(),
    async_command_routes: manifest.registered_async_routes(),
  }
}

///|
fn macos_start_service_operation_json(service_json : String) -> String {
  "{\"kind\":\"start-service\",\"service\":\{service_json}}"
}

///|
fn macos_bundled_lifecycle_event_json(
  event : @bundled.BundledLifecycleEvent,
) -> String {
  if event.label() == "" {
    "{\"kind\":\{event.kind().json_string()}}"
  } else {
    [
      "{",
      "\"kind\":\{event.kind().json_string()},",
      "\"label\":\{event.label().json_string()}",
      "}",
    ].join("")
  }
}

///|
fn macos_operation_jsons_from_runtime_action_json(
  action_json : String,
  webviews : Array[@bundled.BundledWebView],
) -> Result[Array[String], String] {
  try @json.parse(action_json) catch {
    error => Err("invalid runtime action json: \{error}")
  } noraise {
    Object(action) =>
      match optional_response_string(action, "kind").unwrap_or("") {
        "effect" =>
          Ok([
            [
              "{",
              "\"kind\":\"run-effect\",",
              "\"name\":\{optional_response_string(action, "name").unwrap_or("").json_string()}",
              "}",
            ].join(""),
          ])
        "emit" =>
          match (action.get("target"), action.get("event")) {
            (Some(target), Some(event)) =>
              macos_event_operation_jsons(target, event, webviews)
            _ => Err("runtime emit action requires target and event")
          }
        "navigate" =>
          Ok([
            [
              "{",
              "\"kind\":\"navigate-window\",",
              "\"label\":\{optional_response_string(action, "windowLabel").unwrap_or("").json_string()},",
              "\"url\":\{optional_response_string(action, "url").unwrap_or("").json_string()}",
              "}",
            ].join(""),
          ])
        kind => Err("unsupported runtime action kind for macOS: \{kind}")
      }
    _ => Err("runtime action must be a json object")
  }
}

///|
fn macos_event_operation_jsons(
  target : Json,
  event_json : Json,
  webviews : Array[@bundled.BundledWebView],
) -> Result[Array[String], String] {
  match macos_event_from_json(event_json) {
    None => Err("runtime emit event must be a json object")
    Some(event) => {
      let operations : Array[String] = []
      for webview in webviews {
        if macos_target_matches_webview(target, webview) {
          operations.push(macos_dispatch_operation_json(webview, event))
        }
      }
      if operations.is_empty() {
        Err("runtime emit target did not match a webview")
      } else {
        Ok(operations)
      }
    }
  }
}

///|
fn macos_event_from_json(value : Json) -> @lepusa.Event? {
  match value {
    Object(event) =>
      Some(
        @lepusa.Event::new(
          optional_response_string(event, "name").unwrap_or(""),
          payload=optional_response_string(event, "payload").unwrap_or(""),
        ),
      )
    _ => None
  }
}

///|
fn macos_target_matches_webview(
  target : Json,
  webview : @bundled.BundledWebView,
) -> Bool {
  match target {
    Object(object) =>
      match optional_response_string(object, "kind").unwrap_or("") {
        "app" => true
        "window" | "webview" =>
          optional_response_string(object, "label").unwrap_or("") ==
          webview.label()
        _ => false
      }
    _ => false
  }
}

///|
fn macos_dispatch_operation_json(
  webview : @bundled.BundledWebView,
  event : @lepusa.Event,
) -> String {
  let dispatch = @lepusa.FrontendEventDispatch::new(
    window_label=webview.label(),
    hook=webview.event_dispatch_hook(),
    event~,
  )
  [
    "{",
    "\"kind\":\"dispatch-event\",",
    "\"dispatch\":\{dispatch.to_json()}",
    "}",
  ].join("")
}

///|
pub fn run(
  runtime : @runtime.NativeRuntime,
  mode? : MacOSRunMode = MacOSDryRun,
) -> Result[MacOSRunResult, Array[String]] {
  match prepare_run(runtime) {
    Err(problems) => Err(problems)
    Ok(plan) =>
      run_plan(
        plan,
        mode~,
        dispatch=runtime_dispatch(runtime),
        resolve_asset=runtime_asset_resolver(runtime),
      )
  }
}

///|
pub fn run_bundled(
  manifest : @bundled.BundledRuntimeManifest,
  mode? : MacOSRunMode = MacOSDryRun,
) -> Result[MacOSRunResult, Array[String]] {
  match prepare_bundled_run(manifest) {
    Err(problems) => Err(problems)
    Ok(plan) =>
      run_plan(
        plan,
        mode~,
        dispatch=bundled_dispatch(manifest),
        resolve_asset=bundled_asset_resolver(manifest),
      )
  }
}

///|
pub fn launch(
  runtime : @runtime.NativeRuntime,
) -> Result[MacOSRunResult, Array[String]] {
  run(runtime, mode=MacOSOpenWindow)
}

///|
pub fn launch_bundled(
  manifest : @bundled.BundledRuntimeManifest,
) -> Result[MacOSRunResult, Array[String]] {
  run_bundled(manifest, mode=MacOSOpenWindow)
}

///|
pub fn MacOSRunPlan::webviews(
  self : MacOSRunPlan,
) -> Array[@runtime.NativeWebViewPlan] {
  self.webviews.copy()
}

///|
pub fn MacOSRunPlan::first_webview(
  self : MacOSRunPlan,
) -> Result[@runtime.NativeWebViewPlan, String] {
  match self.webviews.get(0) {
    Some(webview) => Ok(webview)
    None => Err("macOS run plan requires at least one webview")
  }
}

///|
pub fn MacOSRunPlan::execution(self : MacOSRunPlan) -> MacOSExecutionPlan {
  self.execution
}

///|
pub fn MacOSRunPlan::bridge(self : MacOSRunPlan) -> MacOSBridgePlan {
  self.bridge
}

///|
pub fn MacOSRunPlan::service_supervisor_plan(
  self : MacOSRunPlan,
) -> @runtime.NativeServiceSupervisorPlan {
  self.service_supervisor
}

///|
pub fn MacOSRunPlan::service_supervisor_report(
  self : MacOSRunPlan,
) -> @runtime.NativeServiceSupervisorReport {
  self.service_supervisor.prepared_report()
}

///|
pub fn MacOSBridgePlan::sync_command_routes(
  self : MacOSBridgePlan,
) -> Array[String] {
  self.sync_command_routes.copy()
}

///|
pub fn MacOSBridgePlan::async_command_routes(
  self : MacOSBridgePlan,
) -> Array[String] {
  self.async_command_routes.copy()
}

///|
pub fn MacOSBridgePlan::requires_async_dispatch(self : MacOSBridgePlan) -> Bool {
  !self.async_command_routes.is_empty()
}

///|
pub fn MacOSExecutionPlan::startup_operations(
  self : MacOSExecutionPlan,
) -> Array[String] {
  self.startup_operations.copy()
}

///|
pub fn MacOSExecutionPlan::lifecycle_steps(
  self : MacOSExecutionPlan,
) -> Array[MacOSLifecycleStepPlan] {
  self.lifecycle_steps.copy()
}

///|
pub fn MacOSLifecycleStepPlan::event_json(
  self : MacOSLifecycleStepPlan,
) -> String {
  self.event_json
}

///|
pub fn MacOSLifecycleStepPlan::operations(
  self : MacOSLifecycleStepPlan,
) -> Array[String] {
  self.operations.copy()
}

///|
pub fn MacOSRunResult::plan(self : MacOSRunResult) -> MacOSRunPlan {
  self.plan
}

///|
pub fn MacOSRunResult::status(self : MacOSRunResult) -> @lepusa.RunStatus {
  self.status
}

///|
fn run_plan(
  plan : MacOSRunPlan,
  mode~ : MacOSRunMode,
  dispatch~ : (Bytes) -> Bytes,
  resolve_asset~ : (Bytes) -> Bytes,
) -> Result[MacOSRunResult, Array[String]] {
  match mode {
    MacOSDryRun => Ok({ plan, status: RunPrepared })
    MacOSOpenWindow => {
      if plan.bridge().requires_async_dispatch() {
        return Ok({
          plan,
          status: RunUnsupported(async_bridge_launch_message(plan)),
        })
      }
      let webview = match plan.first_webview() {
        Ok(webview) => webview
        Err(problem) => return Err([problem])
      }
      let exit_code = run_webview_with_bridge(
        @utf8.encode(webview.title()),
        @utf8.encode(webview.load_url()),
        @utf8.encode(webview.initialization_script()),
        @utf8.encode(webview.native_hook()),
        @utf8.encode(webview.asset_protocol()),
        webview.width(),
        webview.height(),
        if webview.resizable() {
          1
        } else {
          0
        },
        fn(dispatch, message) { dispatch(message) },
        dispatch,
        fn(resolve_asset, url) { resolve_asset(url) },
        resolve_asset,
      )
      if exit_code == 0 {
        Ok({ plan, status: RunLaunched })
      } else {
        Ok({ plan, status: RunFailed("macOS WebView launch failed") })
      }
    }
  }
}

///|
fn async_bridge_launch_message(plan : MacOSRunPlan) -> String {
  let routes = plan.bridge().async_command_routes()
  "macOS launch requires native async bridge scheduling for \{routes.length()} async command route(s)"
}

///|
fn runtime_dispatch(runtime : @runtime.NativeRuntime) -> (Bytes) -> Bytes {
  fn(message : Bytes) { runtime.dispatch_bridge_script_bytes(message) }
}

///|
fn runtime_asset_resolver(runtime : @runtime.NativeRuntime) -> (Bytes) -> Bytes {
  fn(url : Bytes) { runtime.resolve_asset_protocol_packet_bytes(url) }
}

///|
fn bundled_dispatch(
  manifest : @bundled.BundledRuntimeManifest,
) -> (Bytes) -> Bytes {
  let runtime = @bundled.BundledRuntime::new(manifest)
  fn(message : Bytes) { runtime.dispatch_bridge_script_bytes(message) }
}

///|
fn bundled_asset_resolver(
  manifest : @bundled.BundledRuntimeManifest,
) -> (Bytes) -> Bytes {
  fn(url : Bytes) { manifest.resolve_asset_protocol_packet_bytes(url) }
}

///|
fn optional_response_string(
  object : Map[String, Json],
  key : String,
) -> String? {
  match object.get(key) {
    Some(String(value)) => Some(value)
    _ => None
  }
}

///|
fn json_value_string(value : Json) -> String {
  match value {
    Null => "null"
    True => "true"
    False => "false"
    Number(value, ..) => value.to_string()
    String(value) => value.json_string()
    Array(items) => "[\{items.map(json_value_string).join(",")}]"
    Object(object) => json_object_string(object)
  }
}

///|
fn json_object_string(object : Map[String, Json]) -> String {
  let keys : Array[String] = []
  for key in object.keys() {
    keys.push(key)
  }
  keys.sort()
  let fields : Array[String] = []
  for key in keys {
    match object.get(key) {
      Some(value) =>
        fields.push("\{key.json_string()}:\{json_value_string(value)}")
      None => ()
    }
  }
  "{\{fields.join(",")}}"
}

///|
fn macos_initialization_script(
  native_hook : String,
  initialization_scripts : Array[String],
) -> String {
  let scripts : Array[String] = [macos_native_hook_script(native_hook)]
  for script in initialization_scripts {
    scripts.push(script)
  }
  scripts.join("\n")
}

///|
fn macos_native_hook_script(hook : String) -> String {
  @runtime.native_webkit_bridge_hook_script(hook, platform_name="macOS")
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
