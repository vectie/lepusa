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
#borrow(label, title, url, initialization_script, native_hook, asset_protocol, initial_open_packet, dispatch, resolve_asset)
extern "c" fn native_run_webview(
  label : Bytes,
  title : Bytes,
  url : Bytes,
  initialization_script : Bytes,
  native_hook : Bytes,
  asset_protocol : Bytes,
  initial_open_packet : Bytes,
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
    packet.label(),
    packet.title(),
    packet.load_url(),
    packet.initialization_script(),
    packet.native_hook(),
    packet.asset_protocol(),
    @utf8.encode(linux_initial_open_packet_from_runtime(runtime, plan)),
    packet.width(),
    packet.height(),
    packet.resizable(),
    fn(dispatch, message) { dispatch(message) },
    callbacks.handoff_packet_callback(),
    fn(resolve_asset, url) { resolve_asset(url) },
    runtime.asset_protocol_resolver_callback(),
  )
  linux_status_with_lifecycle_and_shutdown(
    match exit_code {
      0 => RunLaunched
      2 => RunUnsupported("Linux WebKitGTK launch loop is unavailable")
      code => RunFailed("Linux WebKitGTK launch failed: code \{code}")
    },
    lifecycle=Ok(execute_app_will_exit(plan)),
    shutdown=execute_service_shutdown(plan),
  )
}

///|
fn linux_status_with_lifecycle_and_shutdown(
  status : @lepusa.RunStatus,
  lifecycle~ : Result[@runtime.NativeOperationExecutionReport, String],
  shutdown~ : @runtime.NativeServiceSupervisorReport,
) -> @lepusa.RunStatus {
  match status {
    RunLaunched =>
      match lifecycle {
        Err(problem) =>
          RunFailed("Linux app-will-exit lifecycle failed: \{problem}")
        Ok(report) =>
          match report.first_failure_message() {
            Some(message) =>
              RunFailed("Linux app-will-exit lifecycle failed: \{message}")
            None =>
              match
                shutdown.first_failure_message(context="Linux service shutdown") {
                Some(message) => RunFailed(message)
                None => RunLaunched
              }
          }
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
    packet.label(),
    packet.title(),
    packet.load_url(),
    packet.initialization_script(),
    packet.native_hook(),
    packet.asset_protocol(),
    @utf8.encode(linux_initial_open_packet_from_bundled(plan)),
    packet.width(),
    packet.height(),
    packet.resizable(),
    fn(dispatch, message) { dispatch(message) },
    callbacks.handoff_packet_callback(),
    fn(resolve_asset, url) { resolve_asset(url) },
    manifest.asset_protocol_resolver_callback(),
  )
  linux_status_with_lifecycle_and_shutdown(
    linux_status_from_exit_code(exit_code),
    lifecycle=execute_bundled_app_will_exit(plan),
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

///|
fn linux_initial_open_packet_from_runtime(
  runtime : @runtime.NativeRuntime,
  plan : @runtime.NativePreparedRunPlan,
) -> String {
  @runtime.native_initial_webview_open_handoff_packet(
    plan.webviews(),
    bridge_sources=runtime_bridge_sources(runtime),
  )
}

///|
fn runtime_bridge_sources(runtime : @runtime.NativeRuntime) -> Array[String] {
  match runtime.host().webviews() {
    Ok(webviews) =>
      webviews.map(fn(webview) { webview.initialization_scripts().join("\n") })
    Err(_) => []
  }
}

///|
fn linux_initial_open_packet_from_bundled(
  plan : @bundled.BundledNativeRunPlan,
) -> String {
  @runtime.native_initial_webview_open_handoff_packet(
    plan.webviews(),
    bridge_sources=bundled_bridge_sources(plan),
  )
}

///|
fn bundled_bridge_sources(
  plan : @bundled.BundledNativeRunPlan,
) -> Array[String] {
  let execution = match plan.native_execution_plan() {
    Ok(execution) => Some(execution)
    Err(_) => None
  }
  plan
  .bundled_webviews()
  .map(fn(webview) {
    let scripts = webview.initialization_scripts()
    match execution {
      Some(execution) => {
        let startup = execution.startup_initialization_script(webview.label())
        if startup == "" {
          scripts.join("\n")
        } else {
          scripts.push(startup)
          scripts.join("\n")
        }
      }
      None => scripts.join("\n")
    }
  })
}
