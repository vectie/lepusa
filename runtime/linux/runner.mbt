///|
pub(all) enum LinuxRunMode {
  LinuxDryRun
  LinuxOpenWindow
} derive(Debug, Eq)

///|
pub struct LinuxRunResult {
  plan : @runtime.NativePreparedRunPlan
  status : @lepusa.RunStatus
} derive(Debug, Eq)

///|
pub struct LinuxBundledRunResult {
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
) -> Int = "lepusa_linux_run_webview"

///|
pub fn prepare_run(
  runtime : @runtime.NativeRuntime,
) -> Result[@runtime.NativePreparedRunPlan, Array[String]] {
  runtime.prepare_run_plan(
    prepare_webview=fn(spec) { linux_webview_plan_from_spec(runtime, spec) },
    missing_webview_message="Linux run requires at least one webview",
  )
}

///|
pub fn run(
  runtime : @runtime.NativeRuntime,
  mode? : LinuxRunMode = LinuxDryRun,
) -> Result[LinuxRunResult, Array[String]] {
  match prepare_run(runtime) {
    Err(problems) => Err(problems)
    Ok(plan) =>
      Ok({
        plan,
        status: match mode {
          LinuxDryRun => RunPrepared
          LinuxOpenWindow => linux_open_window(plan, runtime)
        },
      })
  }
}

///|
pub fn launch(
  runtime : @runtime.NativeRuntime,
) -> Result[LinuxRunResult, Array[String]] {
  run(runtime, mode=LinuxOpenWindow)
}

///|
pub fn prepare_bundled_run(
  manifest : @bundled.BundledRuntimeManifest,
) -> Result[@bundled.BundledNativeRunPlan, Array[String]] {
  manifest.prepare_native_run_plan(
    target="linux",
    target_name="Linux",
    prepare_webview=fn(webview) {
      linux_webview_plan_from_bundled(manifest, webview)
    },
    missing_webview_message="Linux bundled run requires at least one webview",
  )
}

///|
pub fn run_bundled(
  manifest : @bundled.BundledRuntimeManifest,
  mode? : LinuxRunMode = LinuxDryRun,
) -> Result[LinuxBundledRunResult, Array[String]] {
  match prepare_bundled_run(manifest) {
    Err(problems) => Err(problems)
    Ok(plan) =>
      Ok({
        plan,
        status: match mode {
          LinuxDryRun => RunPrepared
          LinuxOpenWindow => linux_open_bundled_window(plan, manifest)
        },
      })
  }
}

///|
pub fn launch_bundled(
  manifest : @bundled.BundledRuntimeManifest,
) -> Result[LinuxBundledRunResult, Array[String]] {
  run_bundled(manifest, mode=LinuxOpenWindow)
}

///|
pub fn LinuxRunResult::plan(
  self : LinuxRunResult,
) -> @runtime.NativePreparedRunPlan {
  self.plan
}

///|
pub fn LinuxRunResult::status(self : LinuxRunResult) -> @lepusa.RunStatus {
  self.status
}

///|
pub fn LinuxRunResult::execution_plan(
  self : LinuxRunResult,
) -> @runtime.NativeExecutionPlan {
  self.plan.execution_plan()
}

///|
pub fn LinuxRunResult::launch_session(
  self : LinuxRunResult,
  bridge_mode? : @runtime.NativeBridgeSchedulerMode = NativeBridgeSyncOnly,
) -> @runtime.NativeLaunchSession {
  self.plan.launch_session(bridge_mode~)
}

///|
pub fn LinuxBundledRunResult::plan(
  self : LinuxBundledRunResult,
) -> @bundled.BundledNativeRunPlan {
  self.plan
}

///|
pub fn LinuxBundledRunResult::status(
  self : LinuxBundledRunResult,
) -> @lepusa.RunStatus {
  self.status
}

///|
pub fn LinuxBundledRunResult::execution_plan(
  self : LinuxBundledRunResult,
) -> Result[@runtime.NativeExecutionPlan, String] {
  self.plan.native_execution_plan()
}

///|
pub fn LinuxBundledRunResult::launch_session(
  self : LinuxBundledRunResult,
  bridge_mode? : @runtime.NativeBridgeSchedulerMode = NativeBridgeSyncOnly,
) -> Result[@runtime.NativeLaunchSession, String] {
  self.plan.launch_session(bridge_mode~)
}

///|
pub fn LinuxBundledRunResult::report(
  self : LinuxBundledRunResult,
) -> @lepusa.RunReport {
  let capability = launch_capability()
  let blocker = match
    self.plan.launch_blocker_with_capability("Linux", capability) {
    Some(message) => message
    None => ""
  }
  let execution_report = match self.plan.native_execution_plan() {
    Ok(execution) => Some(operation_executor().execute_startup(execution))
    Err(_) => None
  }
  self.plan.report(
    status=self.status,
    load_url=self.plan.first_webview_load_url(),
    execution_report~,
    target_can_launch=blocker == "",
    target_launch_blocker=blocker,
  )
}

///|
fn linux_webview_plan_from_spec(
  runtime : @runtime.NativeRuntime,
  spec : @runtime.RuntimeWebViewSpec,
) -> Result[@runtime.NativeWebViewPlan, String] {
  runtime.webview_plan(
    spec,
    initialization_script=linux_initialization_script(
      spec.native_hook(),
      spec.initialization_scripts(),
    ),
  )
}

///|
fn linux_open_window(
  plan : @runtime.NativePreparedRunPlan,
  runtime : @runtime.NativeRuntime,
) -> @lepusa.RunStatus {
  let capability = launch_capability()
  match plan.launch_blocker_with_capability("Linux", capability) {
    Some(message) => return RunUnsupported(message)
    None => ()
  }
  let session = plan.launch_session_with_capability(capability)
  let context = match session.first_launch_context() {
    Ok(context) => context
    Err(problem) => return RunFailed(problem)
  }
  let packet = context.packet()
  let startup = execute_service_startup(plan)
  match startup.first_failure_message(context="Linux service startup") {
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
  linux_status_with_shutdown(
    match exit_code {
      0 => RunLaunched
      2 => RunUnsupported("Linux WebKitGTK launch loop is unavailable")
      code => RunFailed("Linux WebKitGTK launch failed: code \{code}")
    },
    shutdown=execute_service_shutdown(plan),
  )
}

///|
fn linux_status_with_shutdown(
  status : @lepusa.RunStatus,
  shutdown~ : @runtime.NativeServiceSupervisorReport,
) -> @lepusa.RunStatus {
  match status {
    RunLaunched =>
      match shutdown.first_failure_message(context="Linux service shutdown") {
        Some(message) => RunFailed(message)
        None => RunLaunched
      }
    _ => status
  }
}

///|
fn linux_status_from_exit_code(exit_code : Int) -> @lepusa.RunStatus {
  match exit_code {
    0 => RunLaunched
    2 => RunUnsupported("Linux WebKitGTK launch loop is unavailable")
    code => RunFailed("Linux WebKitGTK launch failed: code \{code}")
  }
}

///|
fn linux_open_bundled_window(
  plan : @bundled.BundledNativeRunPlan,
  manifest : @bundled.BundledRuntimeManifest,
) -> @lepusa.RunStatus {
  let capability = launch_capability()
  match plan.launch_blocker_with_capability("Linux", capability) {
    Some(message) => return RunUnsupported(message)
    None => ()
  }
  let session = match plan.launch_session_with_capability(capability) {
    Ok(session) => session
    Err(problem) => return RunFailed(problem)
  }
  let context = match session.first_launch_context() {
    Ok(context) => context
    Err(problem) => return RunFailed(problem)
  }
  let packet = context.packet()
  let startup = execute_bundled_service_startup(plan)
  match startup.first_failure_message(context="Linux bundled service startup") {
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
  linux_status_with_shutdown(
    linux_status_from_exit_code(exit_code),
    shutdown=execute_bundled_service_shutdown(plan),
  )
}

///|
fn linux_webview_plan_from_bundled(
  manifest : @bundled.BundledRuntimeManifest,
  webview : @bundled.BundledWebView,
) -> Result[@runtime.NativeWebViewPlan, String] {
  manifest.webview_plan(
    webview,
    initialization_script=linux_initialization_script(
      webview.native_hook(),
      webview.initialization_scripts(),
    ),
  )
}

///|
fn linux_initialization_script(
  native_hook : String,
  initialization_scripts : Array[String],
) -> String {
  let scripts : Array[String] = [linux_native_hook_script(native_hook)]
  for script in initialization_scripts {
    scripts.push(script)
  }
  scripts.join("\n")
}

///|
fn linux_native_hook_script(hook : String) -> String {
  @runtime.native_webkit_bridge_hook_script(hook, platform_name="Linux")
}
