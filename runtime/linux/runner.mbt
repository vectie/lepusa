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
  asset_protocol : String
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
  webviews : Array[LinuxWebViewPlan]
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
  let bootstrap = match manifest.bootstrap_plan() {
    Ok(bootstrap) => bootstrap
    Err(problem) => return Err([problem])
  }
  let bundled_webviews = match manifest.webviews() {
    Ok(webviews) => webviews
    Err(problem) => return Err([problem])
  }
  let webviews : Array[LinuxWebViewPlan] = []
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
pub fn LinuxWebViewPlan::asset_protocol(self : LinuxWebViewPlan) -> String {
  self.asset_protocol
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
) -> Result[LinuxWebViewPlan, String] {
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
        asset_protocol: spec.asset_protocol(),
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
  if linux_is_protocol_load_url(spec.url(), spec.asset_protocol()) ||
    linux_is_direct_load_url(spec.url()) {
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
    @utf8.encode(webview.asset_protocol()),
    webview.width(),
    webview.height(),
    if webview.resizable() {
      1
    } else {
      0
    },
    fn(dispatch, message) { dispatch(message) },
    linux_dispatch(runtime, plan),
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
    linux_bundled_dispatch(manifest, plan),
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
    @utf8.encode(
      @runtime.native_bridge_response_script(response_hook, response_json),
    )
  }
}

///|
fn linux_bundled_dispatch(
  manifest : @bundled.BundledRuntimeManifest,
  plan : LinuxBundledRunPlan,
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
    @utf8.encode(
      @runtime.native_bridge_response_script(response_hook, response_json),
    )
  }
}

///|
fn linux_runtime_asset_resolver(
  runtime : @runtime.NativeRuntime,
) -> (Bytes) -> Bytes {
  fn(url : Bytes) -> Bytes {
    let input = @utf8.decode(url) catch { _ => "" }
    linux_protocol_packet_from_asset_json(runtime.resolve_asset_json(input))
  }
}

///|
fn linux_bundled_asset_resolver(
  manifest : @bundled.BundledRuntimeManifest,
) -> (Bytes) -> Bytes {
  fn(url : Bytes) -> Bytes {
    let input = @utf8.decode(url) catch { _ => "" }
    linux_protocol_packet_from_asset_json(manifest.resolve_asset_json(input))
  }
}

///|
fn linux_webview_plan_from_bundled(
  manifest : @bundled.BundledRuntimeManifest,
  webview : @bundled.BundledWebView,
) -> Result[LinuxWebViewPlan, String] {
  match linux_bundled_initial_load_url(manifest, webview) {
    Err(problem) => Err(problem)
    Ok(load_url) =>
      Ok({
        label: webview.label(),
        title: webview.title(),
        url: webview.url(),
        load_url,
        initialization_script: linux_initialization_script(
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
fn linux_bundled_initial_load_url(
  manifest : @bundled.BundledRuntimeManifest,
  webview : @bundled.BundledWebView,
) -> Result[String, String] {
  if linux_is_protocol_load_url(webview.url(), manifest.asset_protocol()) ||
    linux_is_direct_load_url(webview.url()) {
    Ok(webview.url())
  } else {
    linux_load_url_from_asset_json(manifest.resolve_asset_json(webview.url()))
  }
}

///|
fn linux_load_url_from_asset_json(json : String) -> Result[String, String] {
  try @json.parse(json) catch {
    error => Err("invalid bundled asset response: \{error}")
  } noraise {
    Object(response) =>
      if linux_optional_response_bool(response, "ok").unwrap_or(false) {
        match linux_optional_response_object(response, "body") {
          Some(body) => {
            let kind = linux_optional_response_string(body, "kind").unwrap_or(
              "",
            )
            match kind {
              "virtual" =>
                Ok(
                  "data:\{linux_optional_response_string(response, "mimeType").unwrap_or("text/plain")};base64,\{@base64.encode(@utf8.encode(linux_optional_response_string(body, "content").unwrap_or("")).view())}",
                )
              "local-file" | "packaged-file" =>
                Ok(
                  linux_file_url(
                    linux_optional_response_string(body, "path").unwrap_or(""),
                  ),
                )
              _ => Err("unsupported bundled asset kind: \{kind}")
            }
          }
          None => Err("bundled asset response body is required")
        }
      } else {
        Err(
          linux_optional_response_string(response, "error").unwrap_or(
            "bundled asset resolution failed",
          ),
        )
      }
    _ => Err("bundled asset response must be a json object")
  }
}

///|
fn linux_protocol_packet_from_asset_json(json : String) -> Bytes {
  try @json.parse(json) catch {
    error => linux_protocol_error_packet("invalid asset response: \{error}")
  } noraise {
    Object(response) =>
      if linux_optional_response_bool(response, "ok").unwrap_or(false) {
        match linux_optional_response_object(response, "body") {
          Some(body) => {
            let mime_type = linux_optional_response_string(response, "mimeType").unwrap_or(
              "application/octet-stream",
            )
            match linux_optional_response_string(body, "kind").unwrap_or("") {
              "virtual" =>
                linux_protocol_ok_packet(
                  "virtual",
                  mime_type,
                  linux_optional_response_string(body, "content").unwrap_or(""),
                )
              "local-file" | "packaged-file" =>
                linux_protocol_ok_packet(
                  "file",
                  mime_type,
                  linux_optional_response_string(body, "path").unwrap_or(""),
                )
              kind =>
                linux_protocol_error_packet("unsupported asset kind: \{kind}")
            }
          }
          None => linux_protocol_error_packet("asset response body is required")
        }
      } else {
        linux_protocol_error_packet(
          linux_optional_response_string(response, "error").unwrap_or(
            "asset resolution failed",
          ),
        )
      }
    _ => linux_protocol_error_packet("asset response must be a json object")
  }
}

///|
fn linux_protocol_ok_packet(
  kind : String,
  mime_type : String,
  body : String,
) -> Bytes {
  @utf8.encode("ok\n\{kind}\n\{mime_type}\n\{body}")
}

///|
fn linux_protocol_error_packet(message : String) -> Bytes {
  @utf8.encode("error\n\{message}")
}

///|
fn linux_is_protocol_load_url(url : String, protocol : String) -> Bool {
  protocol != "" && url.has_prefix("\{protocol}://")
}

///|
fn linux_optional_response_object(
  object : Map[String, Json],
  key : String,
) -> Map[String, Json]? {
  match object.get(key) {
    Some(Object(value)) => Some(value)
    _ => None
  }
}

///|
fn linux_optional_response_string(
  object : Map[String, Json],
  key : String,
) -> String? {
  match object.get(key) {
    Some(String(value)) => Some(value)
    _ => None
  }
}

///|
fn linux_optional_response_bool(
  object : Map[String, Json],
  key : String,
) -> Bool? {
  match object.get(key) {
    Some(True) => Some(true)
    Some(False) => Some(false)
    _ => None
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
