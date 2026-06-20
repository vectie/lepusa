///|
pub(all) enum WindowsRunMode {
  WindowsDryRun
  WindowsOpenWindow
} derive(Debug, Eq)

///|
pub struct WindowsRunResult {
  plan : @runtime.NativePreparedRunPlan
  status : @lepusa.RunStatus
} derive(Debug, Eq)

///|
pub struct WindowsBundledRunResult {
  plan : @bundled.BundledNativeRunPlan
  status : @lepusa.RunStatus
} derive(Debug)

///|
#borrow(title, url, initialization_script, native_hook, asset_protocol, dispatch, resolve_asset)
extern "c" fn native_run_webview(
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
) -> Int = "lepusa_windows_run_webview"

///|
pub fn prepare_run(
  runtime : @runtime.NativeRuntime,
) -> Result[@runtime.NativePreparedRunPlan, Array[String]] {
  runtime.prepare_run_plan(
    prepare_webview=fn(spec) { windows_webview_plan_from_spec(runtime, spec) },
    missing_webview_message="Windows run requires at least one webview",
  )
}

///|
pub fn run(
  runtime : @runtime.NativeRuntime,
  mode? : WindowsRunMode = WindowsDryRun,
) -> Result[WindowsRunResult, Array[String]] {
  match prepare_run(runtime) {
    Err(problems) => Err(problems)
    Ok(plan) =>
      Ok({
        plan,
        status: match mode {
          WindowsDryRun => RunPrepared
          WindowsOpenWindow => windows_open_window(plan, runtime)
        },
      })
  }
}

///|
pub fn launch(
  runtime : @runtime.NativeRuntime,
) -> Result[WindowsRunResult, Array[String]] {
  run(runtime, mode=WindowsOpenWindow)
}

///|
pub fn prepare_bundled_run(
  manifest : @bundled.BundledRuntimeManifest,
) -> Result[@bundled.BundledNativeRunPlan, Array[String]] {
  manifest.prepare_native_run_plan(
    target="windows",
    target_name="Windows",
    prepare_webview=fn(webview) {
      windows_webview_plan_from_bundled(manifest, webview)
    },
    missing_webview_message="Windows bundled run requires at least one webview",
  )
}

///|
pub fn run_bundled(
  manifest : @bundled.BundledRuntimeManifest,
  mode? : WindowsRunMode = WindowsDryRun,
) -> Result[WindowsBundledRunResult, Array[String]] {
  match prepare_bundled_run(manifest) {
    Err(problems) => Err(problems)
    Ok(plan) =>
      Ok({
        plan,
        status: match mode {
          WindowsDryRun => RunPrepared
          WindowsOpenWindow => windows_open_bundled_window(plan, manifest)
        },
      })
  }
}

///|
pub fn launch_bundled(
  manifest : @bundled.BundledRuntimeManifest,
) -> Result[WindowsBundledRunResult, Array[String]] {
  run_bundled(manifest, mode=WindowsOpenWindow)
}

///|
pub fn WindowsRunResult::plan(
  self : WindowsRunResult,
) -> @runtime.NativePreparedRunPlan {
  self.plan
}

///|
pub fn WindowsRunResult::status(self : WindowsRunResult) -> @lepusa.RunStatus {
  self.status
}

///|
pub fn WindowsRunResult::execution_plan(
  self : WindowsRunResult,
) -> @runtime.NativeExecutionPlan {
  self.plan.execution_plan()
}

///|
pub fn WindowsRunResult::launch_session(
  self : WindowsRunResult,
  bridge_mode? : @runtime.NativeBridgeSchedulerMode = NativeBridgeSyncOnly,
) -> @runtime.NativeLaunchSession {
  self.plan.launch_session(bridge_mode~)
}

///|
pub fn WindowsBundledRunResult::plan(
  self : WindowsBundledRunResult,
) -> @bundled.BundledNativeRunPlan {
  self.plan
}

///|
pub fn WindowsBundledRunResult::status(
  self : WindowsBundledRunResult,
) -> @lepusa.RunStatus {
  self.status
}

///|
pub fn WindowsBundledRunResult::execution_plan(
  self : WindowsBundledRunResult,
) -> Result[@runtime.NativeExecutionPlan, String] {
  self.plan.native_execution_plan()
}

///|
pub fn WindowsBundledRunResult::launch_session(
  self : WindowsBundledRunResult,
  bridge_mode? : @runtime.NativeBridgeSchedulerMode = NativeBridgeSyncOnly,
) -> Result[@runtime.NativeLaunchSession, String] {
  self.plan.launch_session(bridge_mode~)
}

///|
pub fn WindowsBundledRunResult::report(
  self : WindowsBundledRunResult,
) -> @lepusa.RunReport {
  let blocker = match
    launch_capability().launch_blocker("Windows", self.plan.bridge_scheduler()) {
    Some(message) => message
    None => ""
  }
  self.plan.report(
    status=self.status,
    load_url=self.plan.first_webview_load_url(),
    target_can_launch=blocker == "",
    target_launch_blocker=blocker,
  )
}

///|
fn windows_webview_plan_from_spec(
  runtime : @runtime.NativeRuntime,
  spec : @runtime.RuntimeWebViewSpec,
) -> Result[@runtime.NativeWebViewPlan, String] {
  runtime.webview_plan(
    spec,
    initialization_script=windows_initialization_script(
      spec.native_hook(),
      spec.initialization_scripts(),
    ),
  )
}

///|
fn windows_webview_plan_from_bundled(
  manifest : @bundled.BundledRuntimeManifest,
  webview : @bundled.BundledWebView,
) -> Result[@runtime.NativeWebViewPlan, String] {
  manifest.webview_plan(
    webview,
    initialization_script=windows_initialization_script(
      webview.native_hook(),
      webview.initialization_scripts(),
    ),
  )
}

///|
fn windows_open_window(
  plan : @runtime.NativePreparedRunPlan,
  runtime : @runtime.NativeRuntime,
) -> @lepusa.RunStatus {
  match launch_capability().launch_blocker("Windows", plan.bridge_scheduler()) {
    Some(message) => return RunUnsupported(message)
    None => ()
  }
  let session = plan.launch_session()
  let context = match session.first_launch_context() {
    Ok(context) => context
    Err(problem) => return RunFailed(problem)
  }
  let packet = context.packet()
  let startup = execute_service_startup(plan)
  match startup.first_failure_message(context="Windows service startup") {
    Some(message) => {
      ignore(execute_service_shutdown(plan))
      return RunFailed(message)
    }
    None => ()
  }
  let adapter = runtime.bridge_loop_adapter()
  let callbacks = adapter.callbacks(window_label=packet.label_text())
  let exit_code = native_run_webview(
    packet.title(),
    packet.load_url(),
    packet.initialization_script(),
    packet.native_hook(),
    packet.asset_protocol(),
    packet.width(),
    packet.height(),
    packet.resizable(),
    fn(dispatch, message) { dispatch(message) },
    callbacks.handoff_callback(),
    fn(resolve_asset, url) { resolve_asset(url) },
    runtime.asset_protocol_resolver_callback(),
  )
  windows_status_with_shutdown(
    windows_status_from_exit_code(exit_code),
    shutdown=execute_service_shutdown(plan),
  )
}

///|
fn windows_open_bundled_window(
  plan : @bundled.BundledNativeRunPlan,
  manifest : @bundled.BundledRuntimeManifest,
) -> @lepusa.RunStatus {
  match launch_capability().launch_blocker("Windows", plan.bridge_scheduler()) {
    Some(message) => return RunUnsupported(message)
    None => ()
  }
  let session = match plan.launch_session() {
    Ok(session) => session
    Err(problem) => return RunFailed(problem)
  }
  let context = match session.first_launch_context() {
    Ok(context) => context
    Err(problem) => return RunFailed(problem)
  }
  let packet = context.packet()
  let startup = execute_bundled_service_startup(plan)
  match
    startup.first_failure_message(context="Windows bundled service startup") {
    Some(message) => {
      ignore(execute_bundled_service_shutdown(plan))
      return RunFailed(message)
    }
    None => ()
  }
  let adapter = manifest.bridge_loop_adapter()
  let callbacks = adapter.callbacks(window_label=packet.label_text())
  let exit_code = native_run_webview(
    packet.title(),
    packet.load_url(),
    packet.initialization_script(),
    packet.native_hook(),
    packet.asset_protocol(),
    packet.width(),
    packet.height(),
    packet.resizable(),
    fn(dispatch, message) { dispatch(message) },
    callbacks.handoff_callback(),
    fn(resolve_asset, url) { resolve_asset(url) },
    manifest.asset_protocol_resolver_callback(),
  )
  windows_status_with_shutdown(
    windows_status_from_exit_code(exit_code),
    shutdown=execute_bundled_service_shutdown(plan),
  )
}

///|
fn windows_status_from_exit_code(exit_code : Int) -> @lepusa.RunStatus {
  match exit_code {
    0 => RunLaunched
    2 => RunUnsupported("Windows WebView2 launch loop is unavailable")
    code => RunFailed("Windows WebView2 launch failed: code \{code}")
  }
}

///|
fn windows_status_with_shutdown(
  status : @lepusa.RunStatus,
  shutdown~ : @runtime.NativeServiceSupervisorReport,
) -> @lepusa.RunStatus {
  match status {
    RunLaunched =>
      match shutdown.first_failure_message(context="Windows service shutdown") {
        Some(message) => RunFailed(message)
        None => RunLaunched
      }
    _ => status
  }
}

///|
fn windows_initialization_script(
  native_hook : String,
  initialization_scripts : Array[String],
) -> String {
  let scripts : Array[String] = [windows_native_hook_script(native_hook)]
  for script in initialization_scripts {
    scripts.push(script)
  }
  scripts.join("\n")
}

///|
fn windows_native_hook_script(hook : String) -> String {
  @runtime.native_webview2_bridge_hook_script(hook)
}
