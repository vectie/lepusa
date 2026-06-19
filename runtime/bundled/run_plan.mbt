///|
pub(all) enum BundledRunMode {
  BundledDryRun
  BundledOpenWindow
} derive(Debug, Eq)

///|
pub(all) enum BundledRunStatus {
  BundledPrepared
  BundledLaunchUnsupported(String)
} derive(Debug, Eq)

///|
pub struct BundledRunPlan {
  target : String
  backend : String
  webview_engine : String
  webviews : Array[BundledWebView]
  service_plan : BundledServicePlan
  startup_operation_count : Int
  lifecycle_step_count : Int
  sync_route_count : Int
  async_route_count : Int
} derive(Debug, Eq)

///|
pub struct BundledRunResult {
  plan : BundledRunPlan
  status : BundledRunStatus
} derive(Debug, Eq)

///|
pub fn BundledRuntimeManifest::run_plan(
  self : BundledRuntimeManifest,
) -> Result[BundledRunPlan, String] {
  let webviews = match self.webviews() {
    Ok(webviews) => webviews
    Err(problem) => return Err(problem)
  }
  let service_plan = match self.service_plan() {
    Ok(plan) => plan
    Err(problem) => return Err(problem)
  }
  let lifecycle_step_count = match self.lifecycle_plans() {
    Ok(plans) => plans.length()
    Err(problem) => return Err(problem)
  }
  Ok({
    target: self.target(),
    backend: bundled_native_backend(self.target(), self.runtime_backend()),
    webview_engine: bundled_webview_engine(self.target()),
    webviews,
    service_plan,
    startup_operation_count: service_plan.startup_services().length() +
    self.startup_action_jsons().length(),
    lifecycle_step_count,
    sync_route_count: self.registered_sync_routes().length(),
    async_route_count: self.registered_async_routes().length(),
  })
}

///|
pub fn BundledRuntimeManifest::run(
  self : BundledRuntimeManifest,
  mode? : BundledRunMode = BundledDryRun,
) -> Result[BundledRunResult, String] {
  match self.run_plan() {
    Err(problem) => Err(problem)
    Ok(plan) =>
      Ok({
        plan,
        status: match mode {
          BundledDryRun => BundledPrepared
          BundledOpenWindow =>
            BundledLaunchUnsupported(
              "\{plan.webview_engine()} launch loop is not implemented for target: \{plan.target()}",
            )
        },
      })
  }
}

///|
pub fn BundledRunResult::plan(self : BundledRunResult) -> BundledRunPlan {
  self.plan
}

///|
pub fn BundledRunResult::status(self : BundledRunResult) -> BundledRunStatus {
  self.status
}

///|
pub fn BundledRunPlan::target(self : BundledRunPlan) -> String {
  self.target
}

///|
pub fn BundledRunPlan::backend(self : BundledRunPlan) -> String {
  self.backend
}

///|
pub fn BundledRunPlan::webview_engine(self : BundledRunPlan) -> String {
  self.webview_engine
}

///|
pub fn BundledRunPlan::webviews(self : BundledRunPlan) -> Array[BundledWebView] {
  self.webviews.copy()
}

///|
pub fn BundledRunPlan::first_webview(self : BundledRunPlan) -> BundledWebView? {
  self.webviews.get(0)
}

///|
pub fn BundledRunPlan::service_plan(
  self : BundledRunPlan,
) -> BundledServicePlan {
  self.service_plan
}

///|
pub fn BundledRunPlan::startup_operation_count(self : BundledRunPlan) -> Int {
  self.startup_operation_count
}

///|
pub fn BundledRunPlan::lifecycle_step_count(self : BundledRunPlan) -> Int {
  self.lifecycle_step_count
}

///|
pub fn BundledRunPlan::sync_route_count(self : BundledRunPlan) -> Int {
  self.sync_route_count
}

///|
pub fn BundledRunPlan::async_route_count(self : BundledRunPlan) -> Int {
  self.async_route_count
}

///|
fn bundled_native_backend(target : String, fallback : String) -> String {
  match target {
    "macos" => "macos"
    "windows" => "windows"
    "linux" => "linux"
    _ => fallback
  }
}

///|
fn bundled_webview_engine(target : String) -> String {
  match target {
    "macos" => "WKWebView"
    "windows" => "WebView2"
    "linux" => "WebKitGTK"
    _ => "SystemWebView"
  }
}
