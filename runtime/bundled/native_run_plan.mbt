///|
pub struct BundledNativeRunPlan {
  bootstrap : BundledBootstrapPlan
  bundled_webviews : Array[BundledWebView]
  webviews : Array[@runtime.NativeWebViewPlan]
} derive(Debug)

///|
pub fn BundledRuntimeManifest::prepare_native_run_plan(
  self : BundledRuntimeManifest,
  target~ : String,
  target_name? : String = target,
  prepare_webview~ : (BundledWebView) -> Result[
    @runtime.NativeWebViewPlan,
    String,
  ],
  missing_webview_message? : String = "bundled run requires at least one webview",
) -> Result[BundledNativeRunPlan, Array[String]] {
  if self.target() != target {
    return Err([
      "\{target_name} bundled run requires target \{target}: \{self.target()}",
    ])
  }
  let bootstrap = match self.bootstrap_plan() {
    Ok(bootstrap) => bootstrap
    Err(problem) => return Err([problem])
  }
  let bundled_webviews = match self.webviews() {
    Ok(webviews) => webviews
    Err(problem) => return Err([problem])
  }
  let webviews : Array[@runtime.NativeWebViewPlan] = []
  let problems : Array[String] = []
  for webview in bundled_webviews {
    match prepare_webview(webview) {
      Ok(plan) => webviews.push(plan)
      Err(problem) => problems.push(problem)
    }
  }
  if webviews.is_empty() {
    problems.push(missing_webview_message)
  }
  if problems.is_empty() {
    Ok({ bootstrap, bundled_webviews, webviews })
  } else {
    Err(problems)
  }
}

///|
pub fn BundledNativeRunPlan::bootstrap(
  self : BundledNativeRunPlan,
) -> BundledBootstrapPlan {
  self.bootstrap
}

///|
pub fn BundledNativeRunPlan::bootstrap_json(
  self : BundledNativeRunPlan,
) -> String {
  self.bootstrap.to_json()
}

///|
pub fn BundledNativeRunPlan::webviews(
  self : BundledNativeRunPlan,
) -> Array[@runtime.NativeWebViewPlan] {
  self.webviews.copy()
}

///|
pub fn BundledNativeRunPlan::bundled_webviews(
  self : BundledNativeRunPlan,
) -> Array[BundledWebView] {
  self.bundled_webviews.copy()
}

///|
pub fn BundledNativeRunPlan::webview_count(self : BundledNativeRunPlan) -> Int {
  self.webviews.length()
}

///|
pub fn BundledNativeRunPlan::first_webview_url(
  self : BundledNativeRunPlan,
) -> String {
  match self.webviews.get(0) {
    Some(webview) => webview.url()
    None => ""
  }
}

///|
pub fn BundledNativeRunPlan::first_webview_load_url(
  self : BundledNativeRunPlan,
) -> String {
  match self.webviews.get(0) {
    Some(webview) => webview.load_url()
    None => ""
  }
}

///|
pub fn BundledNativeRunPlan::first_webview(
  self : BundledNativeRunPlan,
) -> Result[@runtime.NativeWebViewPlan, String] {
  match self.webviews.get(0) {
    Some(webview) => Ok(webview)
    None => Err("bundled run plan requires at least one webview")
  }
}

///|
pub fn BundledNativeRunPlan::startup_operation_count(
  self : BundledNativeRunPlan,
) -> Int {
  self.bootstrap.startup_operations().length()
}

///|
pub fn BundledNativeRunPlan::service_supervisor_plan(
  self : BundledNativeRunPlan,
) -> @runtime.NativeServiceSupervisorPlan {
  let plan = self.bootstrap.run_plan()
  @runtime.NativeServiceSupervisorPlan::new(
    backend_name=plan.backend(),
    webview_engine=plan.webview_engine(),
    plan=plan.service_supervisor_plan(),
  )
}

///|
pub fn BundledNativeRunPlan::service_supervisor_report(
  self : BundledNativeRunPlan,
) -> @runtime.NativeServiceSupervisorReport {
  self.service_supervisor_plan().prepared_report()
}

///|
pub fn BundledNativeRunPlan::lifecycle_step_count(
  self : BundledNativeRunPlan,
) -> Int {
  self.bootstrap.lifecycle_operations().length()
}

///|
pub fn BundledNativeRunPlan::bridge_sync_route_count(
  self : BundledNativeRunPlan,
) -> Int {
  self.bootstrap.run_plan().sync_route_count()
}

///|
pub fn BundledNativeRunPlan::bridge_async_route_count(
  self : BundledNativeRunPlan,
) -> Int {
  self.bootstrap.run_plan().async_route_count()
}

///|
pub fn BundledNativeRunPlan::requires_async_bridge_dispatch(
  self : BundledNativeRunPlan,
) -> Bool {
  self.bridge_async_route_count() > 0
}

///|
pub fn BundledNativeRunPlan::bridge_scheduler(
  self : BundledNativeRunPlan,
  mode? : @runtime.NativeBridgeSchedulerMode = NativeBridgeSyncOnly,
) -> @runtime.NativeBridgeScheduler {
  self.bootstrap.manifest.bridge_scheduler(mode~)
}

///|
pub fn BundledNativeRunPlan::async_bridge_launch_message(
  self : BundledNativeRunPlan,
  platform_name : String,
) -> String {
  self.bridge_scheduler().async_bridge_launch_message(platform_name)
}

///|
pub fn BundledNativeRunPlan::launch_session(
  self : BundledNativeRunPlan,
  bridge_mode? : @runtime.NativeBridgeSchedulerMode = NativeBridgeSyncOnly,
) -> Result[@runtime.NativeLaunchSession, String] {
  match self.native_execution_plan() {
    Ok(execution) =>
      Ok(
        @runtime.NativeLaunchSession::new(
          webviews=self.webviews(),
          execution~,
          bridge_scheduler=self.bridge_scheduler(mode=bridge_mode),
          service_supervisor=self.service_supervisor_plan(),
        ),
      )
    Err(problem) => Err(problem)
  }
}
