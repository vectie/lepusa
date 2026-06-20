///|
pub(all) enum WindowsRunMode {
  WindowsDryRun
  WindowsOpenWindow
} derive(Debug, Eq)

///|
pub struct WindowsRunPlan {
  runner : @runtime.NativeRunnerPlan
  webviews : Array[@runtime.NativeWebViewPlan]
} derive(Debug, Eq)

///|
pub struct WindowsRunResult {
  plan : WindowsRunPlan
  status : @lepusa.RunStatus
} derive(Debug, Eq)

///|
pub struct WindowsBundledRunPlan {
  bootstrap : @bundled.BundledBootstrapPlan
  webviews : Array[@runtime.NativeWebViewPlan]
} derive(Debug)

///|
pub struct WindowsBundledRunResult {
  plan : WindowsBundledRunPlan
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
) -> Result[WindowsRunPlan, Array[String]] {
  let runner = runtime.runner_plan()
  let webviews : Array[@runtime.NativeWebViewPlan] = []
  let problems : Array[String] = []
  for spec in runner.webview_specs() {
    match windows_webview_plan_from_spec(runtime, spec) {
      Ok(webview) => webviews.push(webview)
      Err(problem) => problems.push(problem)
    }
  }
  if webviews.is_empty() {
    problems.push("Windows run requires at least one webview")
  }
  if problems.is_empty() {
    Ok({ runner, webviews })
  } else {
    Err(problems)
  }
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
) -> Result[WindowsBundledRunPlan, Array[String]] {
  if manifest.target() != "windows" {
    return Err([
      "Windows bundled run requires target windows: \{manifest.target()}",
    ])
  }
  let bootstrap = match manifest.bootstrap_plan() {
    Ok(bootstrap) => bootstrap
    Err(problem) => return Err([problem])
  }
  let bundled_webviews = match manifest.webviews() {
    Ok(webviews) => webviews
    Err(problem) => return Err([problem])
  }
  let webviews : Array[@runtime.NativeWebViewPlan] = []
  let problems : Array[String] = []
  for webview in bundled_webviews {
    match windows_webview_plan_from_bundled(manifest, webview) {
      Ok(plan) => webviews.push(plan)
      Err(problem) => problems.push(problem)
    }
  }
  if webviews.is_empty() {
    problems.push("Windows bundled run requires at least one webview")
  }
  if problems.is_empty() {
    Ok({ bootstrap, webviews })
  } else {
    Err(problems)
  }
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
pub fn WindowsRunPlan::runner(
  self : WindowsRunPlan,
) -> @runtime.NativeRunnerPlan {
  self.runner
}

///|
pub fn WindowsRunPlan::webview_count(self : WindowsRunPlan) -> Int {
  self.webviews.length()
}

///|
pub fn WindowsRunPlan::first_webview_url(self : WindowsRunPlan) -> String {
  match self.webviews.get(0) {
    Some(webview) => webview.url()
    None => ""
  }
}

///|
pub fn WindowsRunPlan::first_webview_load_url(self : WindowsRunPlan) -> String {
  match self.webviews.get(0) {
    Some(webview) => webview.load_url()
    None => ""
  }
}

///|
pub fn WindowsRunPlan::first_webview(
  self : WindowsRunPlan,
) -> Result[@runtime.NativeWebViewPlan, String] {
  match self.webviews.get(0) {
    Some(webview) => Ok(webview)
    None => Err("Windows run plan requires at least one webview")
  }
}

///|
pub fn WindowsRunPlan::startup_operation_count(self : WindowsRunPlan) -> Int {
  self.runner.startup_operations().length()
}

///|
pub fn WindowsRunPlan::service_supervisor_plan(
  self : WindowsRunPlan,
) -> @runtime.NativeServiceSupervisorPlan {
  self.runner.service_supervisor_plan()
}

///|
pub fn WindowsRunPlan::service_supervisor_report(
  self : WindowsRunPlan,
) -> @runtime.NativeServiceSupervisorReport {
  self.service_supervisor_plan().prepared_report()
}

///|
pub fn WindowsRunPlan::lifecycle_step_count(self : WindowsRunPlan) -> Int {
  self.runner.lifecycle_steps().length()
}

///|
pub fn WindowsRunResult::plan(self : WindowsRunResult) -> WindowsRunPlan {
  self.plan
}

///|
pub fn WindowsRunResult::status(self : WindowsRunResult) -> @lepusa.RunStatus {
  self.status
}

///|
pub fn WindowsBundledRunPlan::bootstrap(
  self : WindowsBundledRunPlan,
) -> @bundled.BundledBootstrapPlan {
  self.bootstrap
}

///|
pub fn WindowsBundledRunPlan::bootstrap_json(
  self : WindowsBundledRunPlan,
) -> String {
  self.bootstrap.to_json()
}

///|
pub fn WindowsBundledRunPlan::webview_count(
  self : WindowsBundledRunPlan,
) -> Int {
  self.webviews.length()
}

///|
pub fn WindowsBundledRunPlan::first_webview_url(
  self : WindowsBundledRunPlan,
) -> String {
  match self.webviews.get(0) {
    Some(webview) => webview.url()
    None => ""
  }
}

///|
pub fn WindowsBundledRunPlan::first_webview_load_url(
  self : WindowsBundledRunPlan,
) -> String {
  match self.webviews.get(0) {
    Some(webview) => webview.load_url()
    None => ""
  }
}

///|
pub fn WindowsBundledRunPlan::first_webview(
  self : WindowsBundledRunPlan,
) -> Result[@runtime.NativeWebViewPlan, String] {
  match self.webviews.get(0) {
    Some(webview) => Ok(webview)
    None => Err("Windows bundled run plan requires at least one webview")
  }
}

///|
pub fn WindowsBundledRunPlan::startup_operation_count(
  self : WindowsBundledRunPlan,
) -> Int {
  self.bootstrap.startup_operations().length()
}

///|
pub fn WindowsBundledRunPlan::service_supervisor_plan(
  self : WindowsBundledRunPlan,
) -> @runtime.NativeServiceSupervisorPlan {
  let plan = self.bootstrap.run_plan()
  @runtime.NativeServiceSupervisorPlan::new(
    backend_name=plan.backend(),
    webview_engine=plan.webview_engine(),
    plan=plan.service_supervisor_plan(),
  )
}

///|
pub fn WindowsBundledRunPlan::service_supervisor_report(
  self : WindowsBundledRunPlan,
) -> @runtime.NativeServiceSupervisorReport {
  self.service_supervisor_plan().prepared_report()
}

///|
pub fn WindowsBundledRunPlan::lifecycle_step_count(
  self : WindowsBundledRunPlan,
) -> Int {
  self.bootstrap.lifecycle_operations().length()
}

///|
pub fn WindowsBundledRunResult::plan(
  self : WindowsBundledRunResult,
) -> WindowsBundledRunPlan {
  self.plan
}

///|
pub fn WindowsBundledRunResult::status(
  self : WindowsBundledRunResult,
) -> @lepusa.RunStatus {
  self.status
}

///|
pub fn WindowsBundledRunResult::report(
  self : WindowsBundledRunResult,
) -> @lepusa.RunReport {
  self.plan
  .bootstrap()
  .run_plan()
  .report(status=self.status, load_url=self.plan.first_webview_load_url())
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
  plan : WindowsRunPlan,
  runtime : @runtime.NativeRuntime,
) -> @lepusa.RunStatus {
  let webview = match plan.first_webview() {
    Ok(webview) => webview
    Err(problem) => return RunFailed(problem)
  }
  let exit_code = native_run_webview(
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
    windows_dispatch(runtime),
    fn(resolve_asset, url) { resolve_asset(url) },
    windows_runtime_asset_resolver(runtime),
  )
  windows_status_from_exit_code(exit_code)
}

///|
fn windows_open_bundled_window(
  plan : WindowsBundledRunPlan,
  manifest : @bundled.BundledRuntimeManifest,
) -> @lepusa.RunStatus {
  let webview = match plan.first_webview() {
    Ok(webview) => webview
    Err(problem) => return RunFailed(problem)
  }
  let exit_code = native_run_webview(
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
    windows_bundled_dispatch(manifest),
    fn(resolve_asset, url) { resolve_asset(url) },
    windows_bundled_asset_resolver(manifest),
  )
  windows_status_from_exit_code(exit_code)
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
fn windows_dispatch(runtime : @runtime.NativeRuntime) -> (Bytes) -> Bytes {
  fn(message : Bytes) { runtime.dispatch_bridge_script_bytes(message) }
}

///|
fn windows_bundled_dispatch(
  manifest : @bundled.BundledRuntimeManifest,
) -> (Bytes) -> Bytes {
  let runtime = @bundled.BundledRuntime::new(manifest)
  fn(message : Bytes) { runtime.dispatch_bridge_script_bytes(message) }
}

///|
fn windows_runtime_asset_resolver(
  runtime : @runtime.NativeRuntime,
) -> (Bytes) -> Bytes {
  fn(url : Bytes) { runtime.resolve_asset_protocol_packet_bytes(url) }
}

///|
fn windows_bundled_asset_resolver(
  manifest : @bundled.BundledRuntimeManifest,
) -> (Bytes) -> Bytes {
  fn(url : Bytes) { manifest.resolve_asset_protocol_packet_bytes(url) }
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
