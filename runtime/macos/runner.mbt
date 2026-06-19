///|
pub(all) enum MacOSRunMode {
  MacOSDryRun
  MacOSOpenWindow
} derive(Debug, Eq)

///|
pub struct MacOSWebViewPlan {
  label : String
  title : String
  url : String
  load_url : String
  initialization_script : String
  native_hook : String
  asset_protocol : String
  width : Int
  height : Int
  resizable : Bool
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
  webviews : Array[MacOSWebViewPlan]
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
  let runner = runtime.runner_plan()
  let webviews : Array[MacOSWebViewPlan] = []
  let problems : Array[String] = []
  for spec in runner.webview_specs() {
    match macos_webview_plan_from_spec(runtime, spec) {
      Ok(webview) => webviews.push(webview)
      Err(problem) => problems.push(problem)
    }
  }
  if webviews.is_empty() {
    problems.push("macOS run requires at least one webview")
  }
  if problems.is_empty() {
    Ok({
      webviews,
      execution: macos_execution_plan_from_runner(runner),
      bridge: macos_bridge_plan_from_runtime(runtime),
      service_supervisor: runner.service_supervisor_plan(),
    })
  } else {
    Err(problems)
  }
}

///|
fn macos_webview_plan_from_spec(
  runtime : @runtime.NativeRuntime,
  spec : @runtime.RuntimeWebViewSpec,
) -> Result[MacOSWebViewPlan, String] {
  match initial_load_url(runtime, spec) {
    Ok(load_url) =>
      Ok({
        label: spec.label(),
        title: spec.title(),
        url: spec.url(),
        load_url,
        initialization_script: macos_initialization_script(
          spec.native_hook(),
          spec.initialization_scripts(),
        ),
        native_hook: spec.native_hook(),
        asset_protocol: spec.asset_protocol(),
        width: spec.width(),
        height: spec.height(),
        resizable: spec.resizable(),
      })
    Err(problem) => Err(problem)
  }
}

///|
pub fn prepare_bundled_run(
  manifest : @bundled.BundledRuntimeManifest,
) -> Result[MacOSRunPlan, Array[String]] {
  match manifest.webviews() {
    Err(problem) => Err([problem])
    Ok(bundled_webviews) => {
      let webviews : Array[MacOSWebViewPlan] = []
      let problems : Array[String] = []
      for webview in bundled_webviews {
        match macos_webview_plan_from_bundled(manifest, webview) {
          Ok(plan) => webviews.push(plan)
          Err(problem) => problems.push(problem)
        }
      }
      let execution = match macos_execution_plan_from_bundled(manifest) {
        Ok(execution) => Some(execution)
        Err(execution_problems) => {
          for problem in execution_problems {
            problems.push(problem)
          }
          None
        }
      }
      let service_supervisor = match
        macos_service_supervisor_from_bundled(manifest) {
        Ok(plan) => Some(plan)
        Err(problem) => {
          problems.push(problem)
          None
        }
      }
      match (execution, service_supervisor) {
        (Some(execution), Some(service_supervisor)) if problems.is_empty() =>
          Ok({
            webviews,
            execution,
            bridge: macos_bridge_plan_from_bundled(manifest),
            service_supervisor,
          })
        _ => Err(problems)
      }
    }
  }
}

///|
fn macos_webview_plan_from_bundled(
  manifest : @bundled.BundledRuntimeManifest,
  webview : @bundled.BundledWebView,
) -> Result[MacOSWebViewPlan, String] {
  match bundled_initial_load_url(manifest, webview) {
    Err(problem) => Err(problem)
    Ok(load_url) =>
      Ok({
        label: webview.label(),
        title: webview.title(),
        url: webview.url(),
        load_url,
        initialization_script: macos_initialization_script(
          webview.native_hook(),
          webview.initialization_scripts(),
        ),
        native_hook: webview.native_hook(),
        asset_protocol: manifest.asset_protocol(),
        width: webview.width(),
        height: webview.height(),
        resizable: webview.resizable(),
      })
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
) -> Result[MacOSExecutionPlan, Array[String]] {
  let startup_operations : Array[String] = []
  let problems : Array[String] = []
  for service in manifest.local_service_jsons() {
    startup_operations.push(macos_start_service_operation_json(service))
  }
  for action in manifest.startup_action_jsons() {
    match macos_operation_json_from_runtime_action_json(action) {
      Ok(operation) => startup_operations.push(operation)
      Err(problem) => problems.push(problem)
    }
  }
  let lifecycle_steps : Array[MacOSLifecycleStepPlan] = []
  match manifest.lifecycle_plans() {
    Ok(plans) =>
      for plan in plans {
        let operations : Array[String] = []
        for action in plan.action_jsons() {
          match macos_operation_json_from_runtime_action_json(action) {
            Ok(operation) => operations.push(operation)
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
fn macos_service_supervisor_from_bundled(
  manifest : @bundled.BundledRuntimeManifest,
) -> Result[@runtime.NativeServiceSupervisorPlan, String] {
  match manifest.run_plan() {
    Ok(plan) =>
      Ok(
        @runtime.NativeServiceSupervisorPlan::new(
          backend_name=plan.backend(),
          webview_engine=plan.webview_engine(),
          plan=plan.service_supervisor_plan(),
        ),
      )
    Err(problem) => Err(problem)
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
fn macos_operation_json_from_runtime_action_json(
  action_json : String,
) -> Result[String, String] {
  try @json.parse(action_json) catch {
    error => Err("invalid runtime action json: \{error}")
  } noraise {
    Object(action) =>
      match optional_response_string(action, "kind").unwrap_or("") {
        "effect" =>
          Ok(
            [
              "{",
              "\"kind\":\"run-effect\",",
              "\"name\":\{optional_response_string(action, "name").unwrap_or("").json_string()}",
              "}",
            ].join(""),
          )
        "emit" =>
          match (action.get("target"), action.get("event")) {
            (Some(target), Some(event)) =>
              Ok(
                [
                  "{",
                  "\"kind\":\"send-event\",",
                  "\"target\":\{json_value_string(target)},",
                  "\"event\":\{json_value_string(event)}",
                  "}",
                ].join(""),
              )
            _ => Err("runtime emit action requires target and event")
          }
        "navigate" =>
          Ok(
            [
              "{",
              "\"kind\":\"navigate-window\",",
              "\"label\":\{optional_response_string(action, "windowLabel").unwrap_or("").json_string()},",
              "\"url\":\{optional_response_string(action, "url").unwrap_or("").json_string()}",
              "}",
            ].join(""),
          )
        kind => Err("unsupported runtime action kind for macOS: \{kind}")
      }
    _ => Err("runtime action must be a json object")
  }
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
        dispatch=runtime_dispatch(runtime, plan),
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
        dispatch=bundled_dispatch(manifest, plan),
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
pub fn MacOSRunPlan::webviews(self : MacOSRunPlan) -> Array[MacOSWebViewPlan] {
  self.webviews.copy()
}

///|
pub fn MacOSRunPlan::first_webview(
  self : MacOSRunPlan,
) -> Result[MacOSWebViewPlan, String] {
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
pub fn MacOSWebViewPlan::label(self : MacOSWebViewPlan) -> String {
  self.label
}

///|
pub fn MacOSWebViewPlan::title(self : MacOSWebViewPlan) -> String {
  self.title
}

///|
pub fn MacOSWebViewPlan::url(self : MacOSWebViewPlan) -> String {
  self.url
}

///|
pub fn MacOSWebViewPlan::load_url(self : MacOSWebViewPlan) -> String {
  self.load_url
}

///|
pub fn MacOSWebViewPlan::initialization_script(
  self : MacOSWebViewPlan,
) -> String {
  self.initialization_script
}

///|
pub fn MacOSWebViewPlan::native_hook(self : MacOSWebViewPlan) -> String {
  self.native_hook
}

///|
pub fn MacOSWebViewPlan::asset_protocol(self : MacOSWebViewPlan) -> String {
  self.asset_protocol
}

///|
pub fn MacOSWebViewPlan::width(self : MacOSWebViewPlan) -> Int {
  self.width
}

///|
pub fn MacOSWebViewPlan::height(self : MacOSWebViewPlan) -> Int {
  self.height
}

///|
pub fn MacOSWebViewPlan::resizable(self : MacOSWebViewPlan) -> Bool {
  self.resizable
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
fn initial_load_url(
  runtime : @runtime.NativeRuntime,
  spec : @runtime.RuntimeWebViewSpec,
) -> Result[String, String] {
  if is_protocol_load_url(spec.url(), spec.asset_protocol()) ||
    is_direct_load_url(spec.url()) {
    Ok(spec.url())
  } else {
    match runtime.host().snapshot() {
      Err(problems) =>
        Err(problems.get(0).unwrap_or("runtime session is invalid"))
      Ok(session) =>
        match session.resolve_asset(spec.url()) {
          Ok(asset) => macos_load_url_from_asset(asset)
          Err(problem) => Err(problem)
        }
    }
  }
}

///|
fn macos_load_url_from_asset(
  asset : @runtime.RuntimeAssetResponse,
) -> Result[String, String] {
  match asset.body() {
    VirtualContent(content) =>
      Ok(
        "data:\{asset.mime_type()};base64,\{@base64.encode(@utf8.encode(content).view())}",
      )
    LocalFile(path) | PackagedFile(path) => Ok(file_url(path))
  }
}

///|
fn file_url(path : String) -> String {
  if path.has_prefix("file://") {
    path
  } else if path.has_prefix("/") {
    "file://\{path}"
  } else {
    "file://\{path}"
  }
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
        @utf8.encode(webview.title),
        @utf8.encode(webview.load_url),
        @utf8.encode(webview.initialization_script),
        @utf8.encode(webview.native_hook),
        @utf8.encode(webview.asset_protocol),
        webview.width,
        webview.height,
        if webview.resizable {
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
fn runtime_dispatch(
  runtime : @runtime.NativeRuntime,
  plan : MacOSRunPlan,
) -> (Bytes) -> Bytes {
  let response_hook = match plan.first_webview() {
    Ok(webview) => "\{webview.native_hook()}Response"
    Err(_) => "__lepusaInvokeResponse"
  }
  fn(message : Bytes) -> Bytes {
    let input = @utf8.decode(message) catch { _ => "" }
    let response_json = runtime.dispatch_json(input)
    @utf8.encode(bridge_response_script(response_hook, response_json))
  }
}

///|
fn runtime_asset_resolver(runtime : @runtime.NativeRuntime) -> (Bytes) -> Bytes {
  fn(url : Bytes) -> Bytes {
    let input = @utf8.decode(url) catch { _ => "" }
    macos_protocol_packet_from_asset_json(runtime.resolve_asset_json(input))
  }
}

///|
fn bundled_dispatch(
  manifest : @bundled.BundledRuntimeManifest,
  plan : MacOSRunPlan,
) -> (Bytes) -> Bytes {
  let response_hook = match plan.first_webview() {
    Ok(webview) => "\{webview.native_hook()}Response"
    Err(_) => "__lepusaInvokeResponse"
  }
  fn(message : Bytes) -> Bytes {
    let input = @utf8.decode(message) catch { _ => "" }
    let response_json = match @runtime.decode_invoke_request_json(input) {
      Ok(request) =>
        manifest.dispatch_json(
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
    @utf8.encode(bridge_response_script(response_hook, response_json))
  }
}

///|
fn bundled_asset_resolver(
  manifest : @bundled.BundledRuntimeManifest,
) -> (Bytes) -> Bytes {
  fn(url : Bytes) -> Bytes {
    let input = @utf8.decode(url) catch { _ => "" }
    macos_protocol_packet_from_asset_json(manifest.resolve_asset_json(input))
  }
}

///|
fn bundled_initial_load_url(
  manifest : @bundled.BundledRuntimeManifest,
  webview : @bundled.BundledWebView,
) -> Result[String, String] {
  if is_protocol_load_url(webview.url(), manifest.asset_protocol()) ||
    is_direct_load_url(webview.url()) {
    Ok(webview.url())
  } else {
    bundled_load_url_from_asset_json(manifest.resolve_asset_json(webview.url()))
  }
}

///|
fn bundled_load_url_from_asset_json(json : String) -> Result[String, String] {
  try @json.parse(json) catch {
    error => Err("invalid bundled asset response: \{error}")
  } noraise {
    Object(response) =>
      if optional_response_bool(response, "ok").unwrap_or(false) {
        match optional_response_object(response, "body") {
          Some(body) => {
            let kind = optional_response_string(body, "kind").unwrap_or("")
            match kind {
              "virtual" =>
                Ok(
                  "data:\{optional_response_string(response, "mimeType").unwrap_or("text/plain")};base64,\{@base64.encode(@utf8.encode(optional_response_string(body, "content").unwrap_or("")).view())}",
                )
              "local-file" | "packaged-file" =>
                Ok(
                  file_url(optional_response_string(body, "path").unwrap_or("")),
                )
              _ => Err("unsupported bundled asset kind: \{kind}")
            }
          }
          None => Err("bundled asset response body is required")
        }
      } else {
        Err(
          optional_response_string(response, "error").unwrap_or(
            "bundled asset resolution failed",
          ),
        )
      }
    _ => Err("bundled asset response must be a json object")
  }
}

///|
fn macos_protocol_packet_from_asset_json(json : String) -> Bytes {
  try @json.parse(json) catch {
    error => macos_protocol_error_packet("invalid asset response: \{error}")
  } noraise {
    Object(response) =>
      if optional_response_bool(response, "ok").unwrap_or(false) {
        match optional_response_object(response, "body") {
          Some(body) => {
            let mime_type = optional_response_string(response, "mimeType").unwrap_or(
              "application/octet-stream",
            )
            match optional_response_string(body, "kind").unwrap_or("") {
              "virtual" =>
                macos_protocol_ok_packet(
                  "virtual",
                  mime_type,
                  optional_response_string(body, "content").unwrap_or(""),
                )
              "local-file" | "packaged-file" =>
                macos_protocol_ok_packet(
                  "file",
                  mime_type,
                  optional_response_string(body, "path").unwrap_or(""),
                )
              kind =>
                macos_protocol_error_packet("unsupported asset kind: \{kind}")
            }
          }
          None => macos_protocol_error_packet("asset response body is required")
        }
      } else {
        macos_protocol_error_packet(
          optional_response_string(response, "error").unwrap_or(
            "asset resolution failed",
          ),
        )
      }
    _ => macos_protocol_error_packet("asset response must be a json object")
  }
}

///|
fn macos_protocol_ok_packet(
  kind : String,
  mime_type : String,
  body : String,
) -> Bytes {
  @utf8.encode("ok\n\{kind}\n\{mime_type}\n\{body}")
}

///|
fn macos_protocol_error_packet(message : String) -> Bytes {
  @utf8.encode("error\n\{message}")
}

///|
fn is_direct_load_url(url : String) -> Bool {
  url.has_prefix("http://") ||
  url.has_prefix("https://") ||
  url.has_prefix("file://") ||
  url.has_prefix("data:")
}

///|
fn is_protocol_load_url(url : String, protocol : String) -> Bool {
  protocol != "" && url.has_prefix("\{protocol}://")
}

///|
fn optional_response_object(
  object : Map[String, Json],
  key : String,
) -> Map[String, Json]? {
  match object.get(key) {
    Some(Object(value)) => Some(value)
    _ => None
  }
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
fn optional_response_bool(object : Map[String, Json], key : String) -> Bool? {
  match object.get(key) {
    Some(True) => Some(true)
    Some(False) => Some(false)
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
  let native_hook = hook.js_string_literal()
  let response_hook = "\{hook}Response".js_string_literal()
  [
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
    "      const handler = globalThis.webkit && globalThis.webkit.messageHandlers && globalThis.webkit.messageHandlers[nativeHook];",
    "      if (!handler || typeof handler.postMessage !== \"function\") {",
    "        reject(new Error(`Missing Lepusa macOS native message handler: ${nativeHook}`));",
    "        return;",
    "      }",
    "      pending.set(String(request.id || \"\"), { resolve, reject });",
    "      handler.postMessage(JSON.stringify(request));",
    "    }),",
    "    configurable: true,",
    "  });",
    "})();",
  ].join("\n")
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
