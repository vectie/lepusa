///|
pub struct BundledNativeRunPlan {
  bootstrap : BundledBootstrapPlan
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
    Ok({ bootstrap, webviews })
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
