///|
pub(all) enum LinuxRunMode {
  LinuxDryRun
  LinuxOpenWindow
} derive(Debug, Eq)

///|
pub struct LinuxWebViewPlan {
  label : String
  title : String
  url : String
  load_url : String
  initialization_script : String
  native_hook : String
  width : Int
  height : Int
  resizable : Bool
} derive(Debug, Eq)

///|
pub struct LinuxRunPlan {
  runner : @runtime.NativeRunnerPlan
  webviews : Array[LinuxWebViewPlan]
} derive(Debug, Eq)

///|
pub struct LinuxRunResult {
  plan : LinuxRunPlan
  status : @lepusa.RunStatus
} derive(Debug, Eq)

///|
pub struct LinuxBundledRunPlan {
  bootstrap : @bundled.BundledBootstrapPlan
} derive(Debug)

///|
pub struct LinuxBundledRunResult {
  plan : LinuxBundledRunPlan
  status : @lepusa.RunStatus
} derive(Debug)

///|
#borrow(title, url, initialization_script, native_hook, dispatch)
extern "c" fn native_run_webview(
  title : Bytes,
  url : Bytes,
  initialization_script : Bytes,
  native_hook : Bytes,
  width : Int,
  height : Int,
  resizable : Int,
  call_dispatch : FuncRef[((Bytes) -> Bytes, Bytes) -> Bytes],
  dispatch : (Bytes) -> Bytes,
) -> Int = "lepusa_linux_run_webview"

///|
pub fn prepare_run(
  runtime : @runtime.NativeRuntime,
) -> Result[LinuxRunPlan, Array[String]] {
  let runner = runtime.runner_plan()
  let webviews : Array[LinuxWebViewPlan] = []
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
  match manifest.bootstrap_plan() {
    Ok(bootstrap) => Ok({ bootstrap, })
    Err(problem) => Err([problem])
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
          LinuxOpenWindow =>
            RunUnsupported("Linux WebKitGTK launch loop is not implemented")
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
pub fn LinuxRunPlan::webviews(self : LinuxRunPlan) -> Array[LinuxWebViewPlan] {
  self.webviews.copy()
}

///|
pub fn LinuxRunPlan::first_webview(
  self : LinuxRunPlan,
) -> Result[LinuxWebViewPlan, String] {
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
pub fn LinuxWebViewPlan::label(self : LinuxWebViewPlan) -> String {
  self.label
}

///|
pub fn LinuxWebViewPlan::title(self : LinuxWebViewPlan) -> String {
  self.title
}

///|
pub fn LinuxWebViewPlan::url(self : LinuxWebViewPlan) -> String {
  self.url
}

///|
pub fn LinuxWebViewPlan::load_url(self : LinuxWebViewPlan) -> String {
  self.load_url
}

///|
pub fn LinuxWebViewPlan::initialization_script(
  self : LinuxWebViewPlan,
) -> String {
  self.initialization_script
}

///|
pub fn LinuxWebViewPlan::native_hook(self : LinuxWebViewPlan) -> String {
  self.native_hook
}

///|
pub fn LinuxWebViewPlan::width(self : LinuxWebViewPlan) -> Int {
  self.width
}

///|
pub fn LinuxWebViewPlan::height(self : LinuxWebViewPlan) -> Int {
  self.height
}

///|
pub fn LinuxWebViewPlan::resizable(self : LinuxWebViewPlan) -> Bool {
  self.resizable
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
  self.bootstrap.run_plan().webviews().length()
}

///|
pub fn LinuxBundledRunPlan::first_webview_url(
  self : LinuxBundledRunPlan,
) -> String {
  match self.bootstrap.run_plan().first_webview() {
    Some(webview) => webview.url()
    None => ""
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
  self.plan.bootstrap().run_plan().report(status=self.status)
}

///|
fn linux_webview_plan_from_spec(
  runtime : @runtime.NativeRuntime,
  spec : @runtime.RuntimeWebViewSpec,
) -> Result[LinuxWebViewPlan, String] {
  match linux_initial_load_url(runtime, spec) {
    Ok(load_url) =>
      Ok({
        label: spec.label(),
        title: spec.title(),
        url: spec.url(),
        load_url,
        initialization_script: linux_initialization_script(
          spec.native_hook(),
          spec.initialization_scripts(),
        ),
        native_hook: spec.native_hook(),
        width: spec.width(),
        height: spec.height(),
        resizable: spec.resizable(),
      })
    Err(problem) => Err(problem)
  }
}

///|
fn linux_initial_load_url(
  runtime : @runtime.NativeRuntime,
  spec : @runtime.RuntimeWebViewSpec,
) -> Result[String, String] {
  if linux_is_direct_load_url(spec.url()) {
    Ok(spec.url())
  } else {
    match runtime.host().snapshot() {
      Err(problems) =>
        Err(problems.get(0).unwrap_or("runtime session is invalid"))
      Ok(session) =>
        match session.resolve_asset(spec.url()) {
          Ok(asset) => linux_load_url_from_asset(asset)
          Err(problem) => Err(problem)
        }
    }
  }
}

///|
fn linux_load_url_from_asset(
  asset : @runtime.RuntimeAssetResponse,
) -> Result[String, String] {
  match asset.body() {
    VirtualContent(content) =>
      Ok(
        "data:\{asset.mime_type()};base64,\{@base64.encode(@utf8.encode(content).view())}",
      )
    LocalFile(path) | PackagedFile(path) => Ok(linux_file_url(path))
  }
}

///|
fn linux_file_url(path : String) -> String {
  if path.has_prefix("file://") {
    path
  } else {
    "file://\{path}"
  }
}

///|
fn linux_is_direct_load_url(url : String) -> Bool {
  url.has_prefix("http://") ||
  url.has_prefix("https://") ||
  url.has_prefix("file://") ||
  url.has_prefix("data:")
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
    webview.width(),
    webview.height(),
    if webview.resizable() {
      1
    } else {
      0
    },
    fn(dispatch, message) { dispatch(message) },
    linux_dispatch(runtime, plan),
  )
  match exit_code {
    0 => RunLaunched
    2 => RunUnsupported("Linux WebKitGTK launch loop is unavailable")
    code => RunFailed("Linux WebKitGTK launch failed: code \{code}")
  }
}

///|
fn linux_dispatch(
  runtime : @runtime.NativeRuntime,
  plan : LinuxRunPlan,
) -> (Bytes) -> Bytes {
  let response_hook = match plan.first_webview() {
    Ok(webview) => "\{webview.native_hook()}Response"
    Err(_) => "__lepusaInvokeResponse"
  }
  fn(message : Bytes) -> Bytes {
    let input = @utf8.decode(message) catch { _ => "" }
    let response_json = runtime.dispatch_json(input)
    @utf8.encode(linux_bridge_response_script(response_hook, response_json))
  }
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
    "        reject(new Error(`Missing Lepusa Linux native message handler: ${nativeHook}`));",
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
fn linux_bridge_response_script(
  response_hook : String,
  response_json : String,
) -> String {
  "globalThis[\{response_hook.js_string_literal()}](\{response_json});"
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
