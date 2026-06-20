///|
pub(all) enum BundledRunMode {
  BundledDryRun
  BundledOpenWindow
} derive(Debug, Eq)

///|
pub struct BundledRunPlan {
  target : String
  backend : String
  webview_engine : String
  bridge_url : String
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
  status : @lepusa.RunStatus
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
    bridge_url: self.bridge_url(),
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
          BundledDryRun => RunPrepared
          BundledOpenWindow =>
            RunUnsupported(
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
pub fn BundledRunResult::status(self : BundledRunResult) -> @lepusa.RunStatus {
  self.status
}

///|
pub fn BundledRunResult::report(self : BundledRunResult) -> @lepusa.RunReport {
  self.plan.report(status=self.status)
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
pub fn BundledRunPlan::bridge_url(self : BundledRunPlan) -> String {
  self.bridge_url
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
pub fn BundledRunPlan::service_supervisor_plan(
  self : BundledRunPlan,
) -> @lepusa.LocalServiceSupervisorPlan {
  self.service_plan.supervisor_plan()
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
pub fn BundledRunPlan::report(
  self : BundledRunPlan,
  status~ : @lepusa.RunStatus,
  load_url? : String = "",
  target_can_launch? : Bool = true,
  target_launch_blocker? : String = "",
) -> @lepusa.RunReport {
  let services = self.service_plan()
  let first_window_url = match self.first_webview() {
    Some(webview) => webview.url()
    None => ""
  }
  let first_window_title = match self.first_webview() {
    Some(webview) => webview.title()
    None => ""
  }
  @lepusa.RunReport::new(
    target=self.target,
    backend=self.backend,
    engine=self.webview_engine,
    status~,
    webviews=self.webviews.length(),
    first_window_title~,
    first_window_url~,
    load_url=if load_url == "" { first_window_url } else { load_url },
    bridge_url=self.bridge_url,
    local_services=services.services().length(),
    service_supervisor=services.requires_supervisor(),
    service_start_order=services.startup_service_names(),
    startup_operations=self.startup_operation_count,
    lifecycle_steps=self.lifecycle_step_count,
    bridge_sync_routes=self.sync_route_count,
    bridge_async_routes=self.async_route_count,
    target_can_launch~,
    target_launch_blocker~,
  )
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
