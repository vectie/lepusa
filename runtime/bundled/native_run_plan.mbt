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
    let execution = match bootstrap.native_execution_plan() {
      Ok(execution) => execution
      Err(problem) => return Err([problem])
    }
    Ok({
      bootstrap,
      bundled_webviews,
      webviews: bundled_webviews_with_startup_scripts(execution, webviews),
    })
  } else {
    Err(problems)
  }
}

///|
fn bundled_webviews_with_startup_scripts(
  execution : @runtime.NativeExecutionPlan,
  webviews : Array[@runtime.NativeWebViewPlan],
) -> Array[@runtime.NativeWebViewPlan] {
  webviews.map(fn(webview) {
    webview.with_initialization_script_suffix(
      execution.startup_initialization_script(webview.label()),
    )
  })
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

///|
pub fn BundledNativeRunPlan::operation_execution_report(
  self : BundledNativeRunPlan,
) -> Result[@runtime.NativeOperationExecutionReport, String] {
  match self.native_execution_plan() {
    Ok(execution) =>
      Ok(@runtime.NativeOperationExecutor::new().execute_startup(execution))
    Err(problem) => Err(problem)
  }
}

///|
pub fn BundledNativeRunPlan::report(
  self : BundledNativeRunPlan,
  status~ : @lepusa.RunStatus,
  load_url? : String = "",
  execution_report? : @runtime.NativeOperationExecutionReport? = None,
  target_can_launch? : Bool = true,
  target_launch_blocker? : String = "",
) -> @lepusa.RunReport {
  let execution = match execution_report {
    Some(report) => Ok(report)
    None => self.operation_execution_report()
  }
  let executable_operations = match execution {
    Ok(report) => report.operation_count()
    Err(_) => 0
  }
  let executed_operations = match execution {
    Ok(report) => report.executed_count()
    Err(_) => 0
  }
  let skipped_operations = match execution {
    Ok(report) => report.skipped_count()
    Err(_) => 0
  }
  let failed_operations = match execution {
    Ok(report) => report.failed_count()
    Err(_) => 1
  }
  let first_execution_failure = match execution {
    Ok(report) => report.first_failure_message().unwrap_or("")
    Err(problem) => problem
  }
  self
  .bootstrap()
  .run_plan()
  .report(
    status~,
    load_url~,
    executable_operations~,
    executed_operations~,
    skipped_operations~,
    failed_operations~,
    first_execution_failure~,
    target_can_launch~,
    target_launch_blocker~,
  )
}

///|
pub fn BundledNativeRunPlan::to_json(
  self : BundledNativeRunPlan,
) -> Result[String, String] {
  match self.launch_session() {
    Ok(session) => {
      let manifest = self.bootstrap.manifest
      let run_plan = self.bootstrap.run_plan()
      Ok(
        [
          "{",
          "\"kind\":\"bundled-native-run-plan\",",
          "\"source\":\"bundle\",",
          "\"manifestPath\":\{manifest.path().json_string()},",
          "\"bundleRoot\":\{manifest.bundle_root().json_string()},",
          "\"target\":\{run_plan.target().json_string()},",
          "\"nativeBackend\":\{run_plan.backend().json_string()},",
          "\"webviewEngine\":\{run_plan.webview_engine().json_string()},",
          "\"webviewCount\":\{self.webview_count()},",
          "\"launchSession\":\{session.to_json()}",
          "}",
        ].join(""),
      )
    }
    Err(problem) => Err(problem)
  }
}
