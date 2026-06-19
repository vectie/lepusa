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
#borrow(title, url)
extern "c" fn run_webview(
  title : Bytes,
  url : Bytes,
  width : Int,
  height : Int,
  resizable : Int,
) -> Int = "lepusa_macos_run_webview"

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
pub fn run(
  runtime : @runtime.NativeRuntime,
  mode? : MacOSRunMode = MacOSDryRun,
) -> Result[MacOSRunResult, Array[String]] {
  match prepare_run(runtime) {
    Err(problems) => Err(problems)
    Ok(plan) =>
      match mode {
        MacOSDryRun => Ok({ plan, status: MacOSPrepared })
        MacOSOpenWindow => {
          let exit_code = run_webview(
            @utf8.encode(plan.title),
            @utf8.encode(plan.load_url),
            plan.width,
            plan.height,
            if plan.resizable {
              1
            } else {
              0
            },
          )
          if exit_code == 0 {
            Ok({ plan, status: MacOSLaunched })
          } else {
            Ok({
              plan,
              status: MacOSLaunchFailed("macOS WebView launch failed"),
            })
          }
        }
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
  if spec.url().has_prefix("http://") ||
    spec.url().has_prefix("https://") ||
    spec.url().has_prefix("file://") ||
    spec.url().has_prefix("data:") {
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
