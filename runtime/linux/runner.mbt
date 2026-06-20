///|
pub(all) enum LinuxRunMode {
  LinuxDryRun
  LinuxOpenWindow
} derive(Debug, Eq)

///|
pub struct LinuxRunPlan {
  runner : @runtime.NativeRunnerPlan
  webviews : Array[@runtime.NativeWebViewPlan]
} derive(Debug, Eq)

///|
pub struct LinuxRunResult {
  plan : LinuxRunPlan
  status : @lepusa.RunStatus
} derive(Debug, Eq)

///|
pub struct LinuxBundledRunPlan {
  bootstrap : @bundled.BundledBootstrapPlan
  webviews : Array[@runtime.NativeWebViewPlan]
} derive(Debug)

///|
pub struct LinuxBundledRunResult {
  plan : LinuxBundledRunPlan
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
) -> Result[LinuxRunPlan, Array[String]] {
  let runner = runtime.runner_plan()
  let webviews : Array[@runtime.NativeWebViewPlan] = []
  let problems : Array[String] = []
  for spec in runner.webview_specs() {
    match linux_webview_plan_from_spec(runtime, spec) {
      Ok(webview) => webviews.push(webview)
      Err(problem) => problems.push(problem)
    }
  }
  if webviews.is_empty() {
    problems.push("Linux run requires at least one webview")
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
) -> Result[LinuxBundledRunPlan, Array[String]] {
  if manifest.target() != "linux" {
    return Err(["Linux bundled run requires target linux: \{manifest.target()}"])
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
    match linux_webview_plan_from_bundled(manifest, webview) {
      Ok(plan) => webviews.push(plan)
      Err(problem) => problems.push(problem)
    }
  }
  if webviews.is_empty() {
    problems.push("Linux bundled run requires at least one webview")
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
pub fn LinuxRunPlan::runner(self : LinuxRunPlan) -> @runtime.NativeRunnerPlan {
  self.runner
}

///|
pub fn LinuxRunPlan::webviews(
  self : LinuxRunPlan,
) -> Array[@runtime.NativeWebViewPlan] {
  self.webviews.copy()
}

///|
pub fn LinuxRunPlan::first_webview(
  self : LinuxRunPlan,
) -> Result[@runtime.NativeWebViewPlan, String] {
  match self.webviews.get(0) {
    Some(webview) => Ok(webview)
    None => Err("Linux run plan requires at least one webview")
  }
}

///|
pub fn LinuxRunPlan::webview_count(self : LinuxRunPlan) -> Int {
  self.webviews.length()
}

///|
pub fn LinuxRunPlan::first_webview_url(self : LinuxRunPlan) -> String {
  match self.webviews.get(0) {
    Some(webview) => webview.url()
    None => ""
  }
}

///|
pub fn LinuxRunPlan::first_webview_load_url(self : LinuxRunPlan) -> String {
  match self.webviews.get(0) {
    Some(webview) => webview.load_url()
    None => ""
  }
}

///|
pub fn LinuxRunPlan::startup_operation_count(self : LinuxRunPlan) -> Int {
  self.runner.startup_operations().length()
}

///|
pub fn LinuxRunPlan::service_supervisor_plan(
  self : LinuxRunPlan,
) -> @runtime.NativeServiceSupervisorPlan {
  self.runner.service_supervisor_plan()
}

///|
pub fn LinuxRunPlan::service_supervisor_report(
  self : LinuxRunPlan,
) -> @runtime.NativeServiceSupervisorReport {
  self.service_supervisor_plan().prepared_report()
}

///|
pub fn LinuxRunPlan::lifecycle_step_count(self : LinuxRunPlan) -> Int {
  self.runner.lifecycle_steps().length()
}

///|
pub fn LinuxRunResult::plan(self : LinuxRunResult) -> LinuxRunPlan {
  self.plan
}

///|
pub fn LinuxRunResult::status(self : LinuxRunResult) -> @lepusa.RunStatus {
  self.status
}

///|
pub fn LinuxBundledRunPlan::bootstrap(
  self : LinuxBundledRunPlan,
) -> @bundled.BundledBootstrapPlan {
  self.bootstrap
}

///|
pub fn LinuxBundledRunPlan::bootstrap_json(
  self : LinuxBundledRunPlan,
) -> String {
  self.bootstrap.to_json()
}

///|
pub fn LinuxBundledRunPlan::webview_count(self : LinuxBundledRunPlan) -> Int {
  self.webviews.length()
}

///|
pub fn LinuxBundledRunPlan::first_webview_url(
  self : LinuxBundledRunPlan,
) -> String {
  match self.webviews.get(0) {
    Some(webview) => webview.url()
    None => ""
  }
}

///|
pub fn LinuxBundledRunPlan::first_webview_load_url(
  self : LinuxBundledRunPlan,
) -> String {
  match self.webviews.get(0) {
    Some(webview) => webview.load_url()
    None => ""
  }
}

///|
pub fn LinuxBundledRunPlan::first_webview(
  self : LinuxBundledRunPlan,
) -> Result[@runtime.NativeWebViewPlan, String] {
  match self.webviews.get(0) {
    Some(webview) => Ok(webview)
    None => Err("Linux bundled run plan requires at least one webview")
  }
}

///|
pub fn LinuxBundledRunPlan::startup_operation_count(
  self : LinuxBundledRunPlan,
) -> Int {
  self.bootstrap.startup_operations().length()
}

///|
pub fn LinuxBundledRunPlan::service_supervisor_plan(
  self : LinuxBundledRunPlan,
) -> @runtime.NativeServiceSupervisorPlan {
  let plan = self.bootstrap.run_plan()
  @runtime.NativeServiceSupervisorPlan::new(
    backend_name=plan.backend(),
    webview_engine=plan.webview_engine(),
    plan=plan.service_supervisor_plan(),
  )
}

///|
pub fn LinuxBundledRunPlan::service_supervisor_report(
  self : LinuxBundledRunPlan,
) -> @runtime.NativeServiceSupervisorReport {
  self.service_supervisor_plan().prepared_report()
}

///|
pub fn LinuxBundledRunPlan::lifecycle_step_count(
  self : LinuxBundledRunPlan,
) -> Int {
  self.bootstrap.lifecycle_operations().length()
}

///|
pub fn LinuxBundledRunResult::plan(
  self : LinuxBundledRunResult,
) -> LinuxBundledRunPlan {
  self.plan
}

///|
pub fn LinuxBundledRunResult::status(
  self : LinuxBundledRunResult,
) -> @lepusa.RunStatus {
  self.status
}

///|
pub fn LinuxBundledRunResult::report(
  self : LinuxBundledRunResult,
) -> @lepusa.RunReport {
  self.plan
  .bootstrap()
  .run_plan()
  .report(status=self.status, load_url=self.plan.first_webview_load_url())
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
  plan : LinuxRunPlan,
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
    linux_dispatch(runtime),
    fn(resolve_asset, url) { resolve_asset(url) },
    linux_runtime_asset_resolver(runtime),
  )
  match exit_code {
    0 => RunLaunched
    2 => RunUnsupported("Linux WebKitGTK launch loop is unavailable")
    code => RunFailed("Linux WebKitGTK launch failed: code \{code}")
  }
}

///|
fn linux_open_bundled_window(
  plan : LinuxBundledRunPlan,
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
    linux_bundled_dispatch(manifest),
    fn(resolve_asset, url) { resolve_asset(url) },
    linux_bundled_asset_resolver(manifest),
  )
  match exit_code {
    0 => RunLaunched
    2 => RunUnsupported("Linux WebKitGTK launch loop is unavailable")
    code => RunFailed("Linux WebKitGTK launch failed: code \{code}")
  }
}

///|
fn linux_dispatch(runtime : @runtime.NativeRuntime) -> (Bytes) -> Bytes {
  fn(message : Bytes) { runtime.dispatch_bridge_script_bytes(message) }
}

///|
fn linux_bundled_dispatch(
  manifest : @bundled.BundledRuntimeManifest,
) -> (Bytes) -> Bytes {
  let runtime = @bundled.BundledRuntime::new(manifest)
  fn(message : Bytes) { runtime.dispatch_bridge_script_bytes(message) }
}

///|
fn linux_runtime_asset_resolver(
  runtime : @runtime.NativeRuntime,
) -> (Bytes) -> Bytes {
  fn(url : Bytes) { runtime.resolve_asset_protocol_packet_bytes(url) }
}

///|
fn linux_bundled_asset_resolver(
  manifest : @bundled.BundledRuntimeManifest,
) -> (Bytes) -> Bytes {
  fn(url : Bytes) { manifest.resolve_asset_protocol_packet_bytes(url) }
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
