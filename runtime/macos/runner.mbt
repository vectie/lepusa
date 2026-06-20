///|
pub(all) enum MacOSRunMode {
  MacOSDryRun
  MacOSOpenWindow
} derive(Debug, Eq)

///|
pub struct MacOSBridgePlan {
  sync_command_routes : Array[String]
  async_command_routes : Array[String]
} derive(Debug, Eq)

///|
pub struct MacOSRunPlan {
  webviews : Array[@runtime.NativeWebViewPlan]
  execution : @runtime.NativeExecutionPlan
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
    execution: plan.execution_plan(),
    bridge: macos_bridge_plan_from_runtime(runtime),
    service_supervisor: plan.service_supervisor_plan(),
  }
}

///|
fn macos_execution_plan_from_bundled(
  plan : @bundled.BundledNativeRunPlan,
) -> Result[@runtime.NativeExecutionPlan, Array[String]] {
  match plan.native_execution_plan() {
    Ok(execution) => Ok(execution)
    Err(problem) => Err([problem])
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
pub fn run(
  runtime : @runtime.NativeRuntime,
  mode? : MacOSRunMode = MacOSDryRun,
) -> Result[MacOSRunResult, Array[String]] {
  match prepare_run(runtime) {
    Err(problems) => Err(problems)
    Ok(plan) => {
      let adapter = runtime.bridge_loop_adapter()
      run_plan(
        plan,
        mode~,
        dispatch_for_window=fn(window_label) {
          adapter.callbacks(window_label~).handoff_packet_callback()
        },
        resolve_asset=runtime.asset_protocol_resolver_callback(),
      )
    }
  }
}

///|
pub fn run_bundled(
  manifest : @bundled.BundledRuntimeManifest,
  mode? : MacOSRunMode = MacOSDryRun,
) -> Result[MacOSRunResult, Array[String]] {
  match prepare_bundled_run(manifest) {
    Err(problems) => Err(problems)
    Ok(plan) => {
      let adapter = manifest.bridge_loop_adapter()
      run_plan(
        plan,
        mode~,
        dispatch_for_window=fn(window_label) {
          adapter.callbacks(window_label~).handoff_packet_callback()
        },
        resolve_asset=manifest.asset_protocol_resolver_callback(),
      )
    }
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
pub fn MacOSRunPlan::execution(
  self : MacOSRunPlan,
) -> @runtime.NativeExecutionPlan {
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
pub fn MacOSRunPlan::launch_session(
  self : MacOSRunPlan,
  bridge_mode? : @runtime.NativeBridgeSchedulerMode = NativeBridgeSyncOnly,
) -> @runtime.NativeLaunchSession {
  @runtime.NativeLaunchSession::new(
    webviews=self.webviews(),
    execution=self.execution(),
    bridge_scheduler=self.bridge().scheduler(mode=bridge_mode),
    service_supervisor=self.service_supervisor_plan(),
  )
}

///|
pub fn MacOSRunPlan::launch_session_with_capability(
  self : MacOSRunPlan,
  capability : @runtime.NativeLaunchCapability,
) -> @runtime.NativeLaunchSession {
  self.launch_session(bridge_mode=capability.bridge_mode())
}

///|
pub fn MacOSRunPlan::launch_blocker_with_capability(
  self : MacOSRunPlan,
  platform_name : String,
  capability : @runtime.NativeLaunchCapability,
) -> String? {
  self
  .launch_session_with_capability(capability)
  .launch_blocker_with_capability(platform_name, capability)
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
  self.scheduler().requires_async_dispatch()
}

///|
pub fn MacOSBridgePlan::scheduler(
  self : MacOSBridgePlan,
  mode? : @runtime.NativeBridgeSchedulerMode = NativeBridgeSyncOnly,
) -> @runtime.NativeBridgeScheduler {
  @runtime.NativeBridgeScheduler::new(
    sync_routes=self.sync_command_routes(),
    async_routes=self.async_command_routes(),
    mode~,
  )
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
  dispatch_for_window~ : (String) -> (Bytes) -> Bytes,
  resolve_asset~ : (Bytes) -> Bytes,
) -> Result[MacOSRunResult, Array[String]] {
  match mode {
    MacOSDryRun => Ok({ plan, status: RunPrepared })
    MacOSOpenWindow => {
      let capability = launch_capability()
      match plan.launch_blocker_with_capability("macOS", capability) {
        Some(message) => return Ok({ plan, status: RunUnsupported(message) })
        None => ()
      }
      let session = plan.launch_session_with_capability(capability)
      let context = match session.first_launch_context() {
        Ok(context) => context
        Err(problem) => return Err([problem])
      }
      let packet = context.packet()
      let startup = plan.execute_service_startup()
      match startup.first_failure_message(context="macOS service startup") {
        Some(message) => {
          ignore(plan.execute_service_shutdown())
          return Ok({ plan, status: RunFailed(message) })
        }
        None => ()
      }
      let dispatch = dispatch_for_window(packet.label_text())
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
      let shutdown = plan.execute_service_shutdown()
      if exit_code == 0 {
        match shutdown.first_failure_message(context="macOS service shutdown") {
          Some(message) => Ok({ plan, status: RunFailed(message) })
          None => Ok({ plan, status: RunLaunched })
        }
      } else {
        Ok({ plan, status: RunFailed("macOS WebView launch failed") })
      }
    }
  }
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
