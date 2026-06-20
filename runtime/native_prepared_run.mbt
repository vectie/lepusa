///|
pub struct NativePreparedRunPlan {
  runner : NativeRunnerPlan
  webviews : Array[NativeWebViewPlan]
} derive(Debug, Eq)

///|
pub fn NativeRuntime::prepare_run_plan(
  self : NativeRuntime,
  prepare_webview~ : (RuntimeWebViewSpec) -> Result[NativeWebViewPlan, String],
  missing_webview_message? : String = "native run requires at least one webview",
) -> Result[NativePreparedRunPlan, Array[String]] {
  let runner = self.runner_plan()
  let webviews : Array[NativeWebViewPlan] = []
  let problems : Array[String] = []
  for spec in runner.webview_specs() {
    match prepare_webview(spec) {
      Ok(webview) => webviews.push(webview)
      Err(problem) => problems.push(problem)
    }
  }
  if webviews.is_empty() {
    problems.push(missing_webview_message)
  }
  if problems.is_empty() {
    Ok({ runner, webviews })
  } else {
    Err(problems)
  }
}

///|
pub fn NativePreparedRunPlan::runner(
  self : NativePreparedRunPlan,
) -> NativeRunnerPlan {
  self.runner
}

///|
pub fn NativePreparedRunPlan::webviews(
  self : NativePreparedRunPlan,
) -> Array[NativeWebViewPlan] {
  self.webviews.copy()
}

///|
pub fn NativePreparedRunPlan::first_webview(
  self : NativePreparedRunPlan,
) -> Result[NativeWebViewPlan, String] {
  match self.webviews.get(0) {
    Some(webview) => Ok(webview)
    None => Err("native run plan requires at least one webview")
  }
}

///|
pub fn NativePreparedRunPlan::webview_count(
  self : NativePreparedRunPlan,
) -> Int {
  self.webviews.length()
}

///|
pub fn NativePreparedRunPlan::first_webview_url(
  self : NativePreparedRunPlan,
) -> String {
  match self.webviews.get(0) {
    Some(webview) => webview.url()
    None => ""
  }
}

///|
pub fn NativePreparedRunPlan::first_webview_load_url(
  self : NativePreparedRunPlan,
) -> String {
  match self.webviews.get(0) {
    Some(webview) => webview.load_url()
    None => ""
  }
}

///|
pub fn NativePreparedRunPlan::startup_operation_count(
  self : NativePreparedRunPlan,
) -> Int {
  self.runner.startup_operations().length()
}

///|
pub fn NativePreparedRunPlan::service_supervisor_plan(
  self : NativePreparedRunPlan,
) -> NativeServiceSupervisorPlan {
  self.runner.service_supervisor_plan()
}

///|
pub fn NativePreparedRunPlan::service_supervisor_report(
  self : NativePreparedRunPlan,
) -> NativeServiceSupervisorReport {
  self.service_supervisor_plan().prepared_report()
}

///|
pub fn NativePreparedRunPlan::lifecycle_step_count(
  self : NativePreparedRunPlan,
) -> Int {
  self.runner.lifecycle_steps().length()
}

///|
pub fn NativePreparedRunPlan::bridge_sync_routes(
  self : NativePreparedRunPlan,
) -> Array[String] {
  self.runner.bridge_sync_routes()
}

///|
pub fn NativePreparedRunPlan::bridge_async_routes(
  self : NativePreparedRunPlan,
) -> Array[String] {
  self.runner.bridge_async_routes()
}

///|
pub fn NativePreparedRunPlan::requires_async_bridge_dispatch(
  self : NativePreparedRunPlan,
) -> Bool {
  self.runner.requires_async_bridge_dispatch()
}

///|
pub fn NativePreparedRunPlan::async_bridge_launch_message(
  self : NativePreparedRunPlan,
  platform_name : String,
) -> String {
  self.bridge_scheduler().async_bridge_launch_message(platform_name)
}

///|
pub fn NativePreparedRunPlan::to_json(self : NativePreparedRunPlan) -> String {
  let runner = self.runner()
  [
    "{",
    "\"kind\":\"native-run-plan\",",
    "\"source\":\"project\",",
    "\"nativeBackend\":\{runner.backend_name().json_string()},",
    "\"webviewEngine\":\{runner.webview_engine().json_string()},",
    "\"webviewCount\":\{self.webview_count()},",
    "\"launchSession\":\{self.launch_session().to_json()}",
    "}",
  ].join("")
}
