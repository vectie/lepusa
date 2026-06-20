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
      match macos_execution_plan_from_bundled(plan) {
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
    .startup_executable_operations()
    .map(fn(operation) { operation.to_json() }),
    lifecycle_steps: runner
    .lifecycle_steps()
    .map(fn(step) {
      {
        event_json: step.event().to_json(),
        operations: step
        .executable_operations()
        .map(fn(operation) { operation.to_json() }),
      }
    }),
  }
}

///|
fn macos_execution_plan_from_bundled(
  plan : @bundled.BundledNativeRunPlan,
) -> Result[MacOSExecutionPlan, Array[String]] {
  let problems : Array[String] = []
  let startup_operations = match plan.startup_executable_operations() {
    Ok(operations) => operations.map(fn(operation) { operation.to_json() })
    Err(problem) => {
      problems.push(problem)
      []
    }
  }
  let lifecycle_steps : Array[MacOSLifecycleStepPlan] = []
  match plan.native_lifecycle_steps() {
    Ok(steps) =>
      for step in steps {
        lifecycle_steps.push({
          event_json: macos_bundled_lifecycle_event_json(step.event()),
          operations: step
          .executable_operations()
          .map(fn(operation) { operation.to_json() }),
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
        dispatch=runtime.bridge_dispatch_callback(),
        resolve_asset=runtime.asset_protocol_resolver_callback(),
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
        dispatch=manifest.bridge_dispatch_callback(),
        resolve_asset=manifest.asset_protocol_resolver_callback(),
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
      let packet = webview.launch_packet()
      let exit_code = run_webview_with_bridge(
        packet.title(),
        packet.load_url(),
        packet.initialization_script(),
        packet.native_hook(),
        packet.asset_protocol(),
        packet.width(),
        packet.height(),
        packet.resizable(),
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
