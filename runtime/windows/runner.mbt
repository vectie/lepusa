///|
pub(all) enum WindowsRunMode {
  WindowsDryRun
  WindowsOpenWindow
} derive(Debug, Eq)

///|
pub struct WindowsWebViewPlan {
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
pub struct WindowsRunPlan {
  runner : @runtime.NativeRunnerPlan
  webviews : Array[WindowsWebViewPlan]
} derive(Debug, Eq)

///|
pub struct WindowsRunResult {
  plan : WindowsRunPlan
  status : @lepusa.RunStatus
} derive(Debug, Eq)

///|
pub struct WindowsBundledRunPlan {
  bootstrap : @bundled.BundledBootstrapPlan
  webviews : Array[WindowsWebViewPlan]
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
  let webviews : Array[WindowsWebViewPlan] = []
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
  let webviews : Array[WindowsWebViewPlan] = []
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
) -> Result[WindowsWebViewPlan, String] {
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
pub fn WindowsWebViewPlan::label(self : WindowsWebViewPlan) -> String {
  self.label
}

///|
pub fn WindowsWebViewPlan::title(self : WindowsWebViewPlan) -> String {
  self.title
}

///|
pub fn WindowsWebViewPlan::url(self : WindowsWebViewPlan) -> String {
  self.url
}

///|
pub fn WindowsWebViewPlan::load_url(self : WindowsWebViewPlan) -> String {
  self.load_url
}

///|
pub fn WindowsWebViewPlan::initialization_script(
  self : WindowsWebViewPlan,
) -> String {
  self.initialization_script
}

///|
pub fn WindowsWebViewPlan::native_hook(self : WindowsWebViewPlan) -> String {
  self.native_hook
}

///|
pub fn WindowsWebViewPlan::asset_protocol(self : WindowsWebViewPlan) -> String {
  self.asset_protocol
}

///|
pub fn WindowsWebViewPlan::width(self : WindowsWebViewPlan) -> Int {
  self.width
}

///|
pub fn WindowsWebViewPlan::height(self : WindowsWebViewPlan) -> Int {
  self.height
}

///|
pub fn WindowsWebViewPlan::resizable(self : WindowsWebViewPlan) -> Bool {
  self.resizable
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
) -> Result[WindowsWebViewPlan, String] {
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
) -> Result[WindowsWebViewPlan, String] {
  match windows_initial_load_url(runtime, spec) {
    Ok(load_url) =>
      Ok({
        label: spec.label(),
        title: spec.title(),
        url: spec.url(),
        load_url,
        initialization_script: windows_initialization_script(
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
fn windows_webview_plan_from_bundled(
  manifest : @bundled.BundledRuntimeManifest,
  webview : @bundled.BundledWebView,
) -> Result[WindowsWebViewPlan, String] {
  match windows_bundled_initial_load_url(manifest, webview) {
    Err(problem) => Err(problem)
    Ok(load_url) =>
      Ok({
        label: webview.label(),
        title: webview.title(),
        url: webview.url(),
        load_url,
        initialization_script: windows_initialization_script(
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
fn windows_initial_load_url(
  runtime : @runtime.NativeRuntime,
  spec : @runtime.RuntimeWebViewSpec,
) -> Result[String, String] {
  if windows_is_protocol_load_url(spec.url(), spec.asset_protocol()) ||
    windows_is_direct_load_url(spec.url()) {
    Ok(spec.url())
  } else {
    match runtime.host().snapshot() {
      Err(problems) =>
        Err(problems.get(0).unwrap_or("runtime session is invalid"))
      Ok(session) =>
        match session.resolve_asset(spec.url()) {
          Ok(asset) => windows_load_url_from_asset(asset)
          Err(problem) => Err(problem)
        }
    }
  }
}

///|
fn windows_bundled_initial_load_url(
  manifest : @bundled.BundledRuntimeManifest,
  webview : @bundled.BundledWebView,
) -> Result[String, String] {
  if windows_is_protocol_load_url(webview.url(), manifest.asset_protocol()) ||
    windows_is_direct_load_url(webview.url()) {
    Ok(webview.url())
  } else {
    windows_load_url_from_asset_json(manifest.resolve_asset_json(webview.url()))
  }
}

///|
fn windows_load_url_from_asset(
  asset : @runtime.RuntimeAssetResponse,
) -> Result[String, String] {
  match asset.body() {
    VirtualContent(content) =>
      Ok(
        "data:\{asset.mime_type()};base64,\{@base64.encode(@utf8.encode(content).view())}",
      )
    LocalFile(path) | PackagedFile(path) => Ok(windows_file_url(path))
  }
}

///|
fn windows_load_url_from_asset_json(json : String) -> Result[String, String] {
  try @json.parse(json) catch {
    error => Err("invalid bundled asset response: \{error}")
  } noraise {
    Object(response) =>
      if windows_optional_response_bool(response, "ok").unwrap_or(false) {
        match windows_optional_response_object(response, "body") {
          Some(body) => {
            let kind = windows_optional_response_string(body, "kind").unwrap_or(
              "",
            )
            match kind {
              "virtual" =>
                Ok(
                  "data:\{windows_optional_response_string(response, "mimeType").unwrap_or("text/plain")};base64,\{@base64.encode(@utf8.encode(windows_optional_response_string(body, "content").unwrap_or("")).view())}",
                )
              "local-file" | "packaged-file" =>
                Ok(
                  windows_file_url(
                    windows_optional_response_string(body, "path").unwrap_or(""),
                  ),
                )
              _ => Err("unsupported bundled asset kind: \{kind}")
            }
          }
          None => Err("bundled asset response body is required")
        }
      } else {
        Err(
          windows_optional_response_string(response, "error").unwrap_or(
            "bundled asset resolution failed",
          ),
        )
      }
    _ => Err("bundled asset response must be a json object")
  }
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
    windows_dispatch(runtime, plan),
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
fn windows_dispatch(
  runtime : @runtime.NativeRuntime,
  plan : WindowsRunPlan,
) -> (Bytes) -> Bytes {
  let response_hook = match plan.first_webview() {
    Ok(webview) => "\{webview.native_hook()}Response"
    Err(_) => "__lepusaInvokeResponse"
  }
  fn(message : Bytes) -> Bytes {
    let input = @utf8.decode(message) catch { _ => "" }
    let response_json = runtime.dispatch_json(input)
    @utf8.encode(
      @runtime.native_bridge_response_script(response_hook, response_json),
    )
  }
}

///|
fn windows_bundled_dispatch(
  manifest : @bundled.BundledRuntimeManifest,
) -> (Bytes) -> Bytes {
  let runtime = @bundled.BundledRuntime::new(manifest)
  fn(message : Bytes) -> Bytes {
    let input = @utf8.decode(message) catch { _ => "" }
    match runtime.dispatch_bridge_message_sync(input) {
      Ok(dispatch) => @utf8.encode(dispatch.evaluation_script())
      Err(_) => @utf8.encode("")
    }
  }
}

///|
fn windows_runtime_asset_resolver(
  runtime : @runtime.NativeRuntime,
) -> (Bytes) -> Bytes {
  fn(url : Bytes) -> Bytes {
    let input = @utf8.decode(url) catch { _ => "" }
    @utf8.encode(runtime.resolve_asset_json(input))
  }
}

///|
fn windows_bundled_asset_resolver(
  manifest : @bundled.BundledRuntimeManifest,
) -> (Bytes) -> Bytes {
  fn(url : Bytes) -> Bytes {
    let input = @utf8.decode(url) catch { _ => "" }
    @utf8.encode(manifest.resolve_asset_json(input))
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

///|
fn windows_file_url(path : String) -> String {
  if path.has_prefix("file://") {
    path
  } else {
    "file://\{path}"
  }
}

///|
fn windows_is_direct_load_url(url : String) -> Bool {
  url.has_prefix("http://") ||
  url.has_prefix("https://") ||
  url.has_prefix("file://") ||
  url.has_prefix("data:")
}

///|
fn windows_is_protocol_load_url(url : String, protocol : String) -> Bool {
  protocol != "" && url.has_prefix("\{protocol}://")
}

///|
fn windows_optional_response_object(
  object : Map[String, Json],
  key : String,
) -> Map[String, Json]? {
  match object.get(key) {
    Some(Object(value)) => Some(value)
    _ => None
  }
}

///|
fn windows_optional_response_string(
  object : Map[String, Json],
  key : String,
) -> String? {
  match object.get(key) {
    Some(String(value)) => Some(value)
    _ => None
  }
}

///|
fn windows_optional_response_bool(
  object : Map[String, Json],
  key : String,
) -> Bool? {
  match object.get(key) {
    Some(True) => Some(true)
    Some(False) => Some(false)
    _ => None
  }
}
