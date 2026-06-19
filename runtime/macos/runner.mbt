///|
pub(all) enum MacOSRunMode {
  MacOSDryRun
  MacOSOpenWindow
} derive(Debug, Eq)

///|
pub(all) enum MacOSRunStatus {
  MacOSPrepared
  MacOSLaunched
  MacOSLaunchFailed(String)
} derive(Debug, Eq)

///|
pub struct MacOSRunPlan {
  title : String
  url : String
  load_url : String
  initialization_script : String
  native_hook : String
  width : Int
  height : Int
  resizable : Bool
  webviews : Int
} derive(Debug, Eq)

///|
pub struct MacOSRunResult {
  plan : MacOSRunPlan
  status : MacOSRunStatus
} derive(Debug, Eq)

///|
#borrow(title, url, initialization_script, native_hook, dispatch)
extern "c" fn run_webview_with_bridge(
  title : Bytes,
  url : Bytes,
  initialization_script : Bytes,
  native_hook : Bytes,
  width : Int,
  height : Int,
  resizable : Int,
  call_dispatch : FuncRef[((Bytes) -> Bytes, Bytes) -> Bytes],
  dispatch : (Bytes) -> Bytes,
) -> Int = "lepusa_macos_run_webview_with_bridge"

///|
pub fn prepare_run(
  runtime : @runtime.NativeRuntime,
) -> Result[MacOSRunPlan, Array[String]] {
  let runner = runtime.runner_plan()
  match runner.webview_specs().get(0) {
    None => Err(["macOS run requires at least one webview"])
    Some(spec) =>
      match initial_load_url(runtime, spec) {
        Ok(load_url) =>
          Ok({
            title: spec.title(),
            url: spec.url(),
            load_url,
            initialization_script: macos_initialization_script(
              spec.native_hook(),
              spec.initialization_scripts(),
            ),
            native_hook: spec.native_hook(),
            width: spec.width(),
            height: spec.height(),
            resizable: spec.resizable(),
            webviews: runner.webview_specs().length(),
          })
        Err(problem) => Err([problem])
      }
  }
}

///|
pub fn prepare_bundled_run(
  manifest : @bundled.BundledRuntimeManifest,
) -> Result[MacOSRunPlan, Array[String]] {
  match manifest.first_webview() {
    Err(problem) => Err([problem])
    Ok(webview) =>
      match bundled_initial_load_url(manifest, webview) {
        Err(problem) => Err([problem])
        Ok(load_url) =>
          Ok({
            title: webview.title(),
            url: webview.url(),
            load_url,
            initialization_script: macos_initialization_script(
              webview.native_hook(),
              webview.initialization_scripts(),
            ),
            native_hook: webview.native_hook(),
            width: webview.width(),
            height: webview.height(),
            resizable: webview.resizable(),
            webviews: manifest.webview_count(),
          })
      }
  }
}

///|
pub fn run(
  runtime : @runtime.NativeRuntime,
  mode? : MacOSRunMode = MacOSDryRun,
) -> Result[MacOSRunResult, Array[String]] {
  match prepare_run(runtime) {
    Err(problems) => Err(problems)
    Ok(plan) => run_plan(plan, mode~, dispatch=runtime_dispatch(runtime, plan))
  }
}

///|
pub fn run_bundled(
  manifest : @bundled.BundledRuntimeManifest,
  mode? : MacOSRunMode = MacOSDryRun,
) -> Result[MacOSRunResult, Array[String]] {
  match prepare_bundled_run(manifest) {
    Err(problems) => Err(problems)
    Ok(plan) => run_plan(plan, mode~, dispatch=bundled_dispatch(manifest, plan))
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
pub fn MacOSRunPlan::title(self : MacOSRunPlan) -> String {
  self.title
}

///|
pub fn MacOSRunPlan::url(self : MacOSRunPlan) -> String {
  self.url
}

///|
pub fn MacOSRunPlan::load_url(self : MacOSRunPlan) -> String {
  self.load_url
}

///|
pub fn MacOSRunPlan::initialization_script(self : MacOSRunPlan) -> String {
  self.initialization_script
}

///|
pub fn MacOSRunPlan::native_hook(self : MacOSRunPlan) -> String {
  self.native_hook
}

///|
pub fn MacOSRunPlan::width(self : MacOSRunPlan) -> Int {
  self.width
}

///|
pub fn MacOSRunPlan::height(self : MacOSRunPlan) -> Int {
  self.height
}

///|
pub fn MacOSRunPlan::resizable(self : MacOSRunPlan) -> Bool {
  self.resizable
}

///|
pub fn MacOSRunPlan::webviews(self : MacOSRunPlan) -> Int {
  self.webviews
}

///|
pub fn MacOSRunResult::plan(self : MacOSRunResult) -> MacOSRunPlan {
  self.plan
}

///|
pub fn MacOSRunResult::status(self : MacOSRunResult) -> MacOSRunStatus {
  self.status
}

///|
fn initial_load_url(
  runtime : @runtime.NativeRuntime,
  spec : @runtime.RuntimeWebViewSpec,
) -> Result[String, String] {
  if is_direct_load_url(spec.url()) {
    Ok(spec.url())
  } else {
    match runtime.host().snapshot() {
      Err(problems) =>
        Err(problems.get(0).unwrap_or("runtime session is invalid"))
      Ok(session) =>
        match session.resolve_asset(spec.url()) {
          Ok(asset) => macos_load_url_from_asset(asset)
          Err(problem) => Err(problem)
        }
    }
  }
}

///|
fn macos_load_url_from_asset(
  asset : @runtime.RuntimeAssetResponse,
) -> Result[String, String] {
  match asset.body() {
    VirtualContent(content) =>
      Ok(
        "data:\{asset.mime_type()};base64,\{@base64.encode(@utf8.encode(content).view())}",
      )
    LocalFile(path) | PackagedFile(path) => Ok(file_url(path))
  }
}

///|
fn file_url(path : String) -> String {
  if path.has_prefix("file://") {
    path
  } else if path.has_prefix("/") {
    "file://\{path}"
  } else {
    "file://\{path}"
  }
}

///|
fn run_plan(
  plan : MacOSRunPlan,
  mode~ : MacOSRunMode,
  dispatch~ : (Bytes) -> Bytes,
) -> Result[MacOSRunResult, Array[String]] {
  match mode {
    MacOSDryRun => Ok({ plan, status: MacOSPrepared })
    MacOSOpenWindow => {
      let exit_code = run_webview_with_bridge(
        @utf8.encode(plan.title),
        @utf8.encode(plan.load_url),
        @utf8.encode(plan.initialization_script),
        @utf8.encode(plan.native_hook),
        plan.width,
        plan.height,
        if plan.resizable {
          1
        } else {
          0
        },
        fn(dispatch, message) { dispatch(message) },
        dispatch,
      )
      if exit_code == 0 {
        Ok({ plan, status: MacOSLaunched })
      } else {
        Ok({ plan, status: MacOSLaunchFailed("macOS WebView launch failed") })
      }
    }
  }
}

///|
fn runtime_dispatch(
  runtime : @runtime.NativeRuntime,
  plan : MacOSRunPlan,
) -> (Bytes) -> Bytes {
  fn(message : Bytes) -> Bytes {
    let input = @utf8.decode(message) catch { _ => "" }
    let response_json = runtime.dispatch_json(input)
    @utf8.encode(
      bridge_response_script("\{plan.native_hook()}Response", response_json),
    )
  }
}

///|
fn bundled_dispatch(
  manifest : @bundled.BundledRuntimeManifest,
  plan : MacOSRunPlan,
) -> (Bytes) -> Bytes {
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
      bridge_response_script("\{plan.native_hook()}Response", response_json),
    )
  }
}

///|
fn bundled_initial_load_url(
  manifest : @bundled.BundledRuntimeManifest,
  webview : @bundled.BundledWebView,
) -> Result[String, String] {
  if is_direct_load_url(webview.url()) {
    Ok(webview.url())
  } else {
    bundled_load_url_from_asset_json(manifest.resolve_asset_json(webview.url()))
  }
}

///|
fn bundled_load_url_from_asset_json(json : String) -> Result[String, String] {
  try @json.parse(json) catch {
    error => Err("invalid bundled asset response: \{error}")
  } noraise {
    Object(response) =>
      if optional_response_bool(response, "ok").unwrap_or(false) {
        match optional_response_object(response, "body") {
          Some(body) => {
            let kind = optional_response_string(body, "kind").unwrap_or("")
            match kind {
              "virtual" =>
                Ok(
                  "data:\{optional_response_string(response, "mimeType").unwrap_or("text/plain")};base64,\{@base64.encode(@utf8.encode(optional_response_string(body, "content").unwrap_or("")).view())}",
                )
              "local-file" | "packaged-file" =>
                Ok(
                  file_url(optional_response_string(body, "path").unwrap_or("")),
                )
              _ => Err("unsupported bundled asset kind: \{kind}")
            }
          }
          None => Err("bundled asset response body is required")
        }
      } else {
        Err(
          optional_response_string(response, "error").unwrap_or(
            "bundled asset resolution failed",
          ),
        )
      }
    _ => Err("bundled asset response must be a json object")
  }
}

///|
fn is_direct_load_url(url : String) -> Bool {
  url.has_prefix("http://") ||
  url.has_prefix("https://") ||
  url.has_prefix("file://") ||
  url.has_prefix("data:")
}

///|
fn optional_response_object(
  object : Map[String, Json],
  key : String,
) -> Map[String, Json]? {
  match object.get(key) {
    Some(Object(value)) => Some(value)
    _ => None
  }
}

///|
fn optional_response_string(
  object : Map[String, Json],
  key : String,
) -> String? {
  match object.get(key) {
    Some(String(value)) => Some(value)
    _ => None
  }
}

///|
fn optional_response_bool(object : Map[String, Json], key : String) -> Bool? {
  match object.get(key) {
    Some(True) => Some(true)
    Some(False) => Some(false)
    _ => None
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
    "        reject(new Error(`Missing Lepusa macOS native message handler: ${nativeHook}`));",
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
