///|
pub(all) enum WindowsRunMode {
  WindowsDryRun
  WindowsOpenWindow
} derive(Debug, Eq)

///|
pub struct WindowsRunPlan {
  runner : @runtime.NativeRunnerPlan
} derive(Debug, Eq)

///|
pub struct WindowsRunResult {
  plan : WindowsRunPlan
  status : @lepusa.RunStatus
} derive(Debug, Eq)

///|
pub struct WindowsBundledRunPlan {
  bootstrap : @bundled.BundledBootstrapPlan
} derive(Debug)

///|
pub struct WindowsBundledRunResult {
  plan : WindowsBundledRunPlan
  status : @lepusa.RunStatus
} derive(Debug)

///|
pub fn prepare_run(
  runtime : @runtime.NativeRuntime,
) -> Result[WindowsRunPlan, Array[String]] {
  Ok({ runner: runtime.runner_plan() })
}

///|
pub fn run(
  runtime : @runtime.NativeRuntime,
  mode? : WindowsRunMode = WindowsDryRun,
) -> Result[WindowsRunResult, Array[String]] {
  match prepare_run(runtime) {
    Err(problems) => Err(problems)
    Ok(plan) =>
      Ok({
        plan,
        status: match mode {
          WindowsDryRun => RunPrepared
          WindowsOpenWindow =>
            RunUnsupported("Windows WebView2 launch loop is not implemented")
        },
      })
  }
}

///|
pub fn launch(
  runtime : @runtime.NativeRuntime,
) -> Result[WindowsRunResult, Array[String]] {
  run(runtime, mode=WindowsOpenWindow)
}

///|
pub fn prepare_bundled_run(
  manifest : @bundled.BundledRuntimeManifest,
) -> Result[WindowsBundledRunPlan, Array[String]] {
  if manifest.target() != "windows" {
    return Err([
      "Windows bundled run requires target windows: \{manifest.target()}",
    ])
  }
  match manifest.bootstrap_plan() {
    Ok(bootstrap) => Ok({ bootstrap, })
    Err(problem) => Err([problem])
  }
}

///|
pub fn run_bundled(
  manifest : @bundled.BundledRuntimeManifest,
  mode? : WindowsRunMode = WindowsDryRun,
) -> Result[WindowsBundledRunResult, Array[String]] {
  match prepare_bundled_run(manifest) {
    Err(problems) => Err(problems)
    Ok(plan) =>
      Ok({
        plan,
        status: match mode {
          WindowsDryRun => RunPrepared
          WindowsOpenWindow =>
            RunUnsupported("Windows WebView2 launch loop is not implemented")
        },
      })
  }
}

///|
pub fn launch_bundled(
  manifest : @bundled.BundledRuntimeManifest,
) -> Result[WindowsBundledRunResult, Array[String]] {
  run_bundled(manifest, mode=WindowsOpenWindow)
}

///|
pub fn WindowsRunPlan::runner(
  self : WindowsRunPlan,
) -> @runtime.NativeRunnerPlan {
  self.runner
}

///|
pub fn WindowsRunPlan::webview_count(self : WindowsRunPlan) -> Int {
  self.runner.webview_specs().length()
}

///|
pub fn WindowsRunPlan::first_webview_url(self : WindowsRunPlan) -> String {
  match self.runner.webview_specs().get(0) {
    Some(webview) => webview.url()
    None => ""
  }
}

///|
pub fn WindowsRunPlan::startup_operation_count(self : WindowsRunPlan) -> Int {
  self.runner.startup_operations().length()
}

///|
pub fn WindowsRunPlan::service_supervisor_plan(
  self : WindowsRunPlan,
) -> @runtime.NativeServiceSupervisorPlan {
  self.runner.service_supervisor_plan()
}

///|
pub fn WindowsRunPlan::service_supervisor_report(
  self : WindowsRunPlan,
) -> @runtime.NativeServiceSupervisorReport {
  self.service_supervisor_plan().prepared_report()
}

///|
pub fn WindowsRunPlan::lifecycle_step_count(self : WindowsRunPlan) -> Int {
  self.runner.lifecycle_steps().length()
}

///|
pub fn WindowsRunResult::plan(self : WindowsRunResult) -> WindowsRunPlan {
  self.plan
}

///|
pub fn WindowsRunResult::status(self : WindowsRunResult) -> @lepusa.RunStatus {
  self.status
}

///|
pub fn WindowsBundledRunPlan::bootstrap(
  self : WindowsBundledRunPlan,
) -> @bundled.BundledBootstrapPlan {
  self.bootstrap
}

///|
pub fn WindowsBundledRunPlan::bootstrap_json(
  self : WindowsBundledRunPlan,
) -> String {
  self.bootstrap.to_json()
}

///|
pub fn WindowsBundledRunPlan::webview_count(
  self : WindowsBundledRunPlan,
) -> Int {
  self.bootstrap.run_plan().webviews().length()
}

///|
pub fn WindowsBundledRunPlan::first_webview_url(
  self : WindowsBundledRunPlan,
) -> String {
  match self.bootstrap.run_plan().first_webview() {
    Some(webview) => webview.url()
    None => ""
  }
}

///|
pub fn WindowsBundledRunPlan::startup_operation_count(
  self : WindowsBundledRunPlan,
) -> Int {
  self.bootstrap.startup_operations().length()
}

///|
pub fn WindowsBundledRunPlan::service_supervisor_plan(
  self : WindowsBundledRunPlan,
) -> @runtime.NativeServiceSupervisorPlan {
  let plan = self.bootstrap.run_plan()
  @runtime.NativeServiceSupervisorPlan::new(
    backend_name=plan.backend(),
    webview_engine=plan.webview_engine(),
    plan=plan.service_supervisor_plan(),
  )
}

///|
pub fn WindowsBundledRunPlan::service_supervisor_report(
  self : WindowsBundledRunPlan,
) -> @runtime.NativeServiceSupervisorReport {
  self.service_supervisor_plan().prepared_report()
}

///|
pub fn WindowsBundledRunPlan::lifecycle_step_count(
  self : WindowsBundledRunPlan,
) -> Int {
  self.bootstrap.lifecycle_operations().length()
}

///|
pub fn WindowsBundledRunResult::plan(
  self : WindowsBundledRunResult,
) -> WindowsBundledRunPlan {
  self.plan
}

///|
pub fn WindowsBundledRunResult::status(
  self : WindowsBundledRunResult,
) -> @lepusa.RunStatus {
  self.status
}

///|
pub fn WindowsBundledRunResult::report(
  self : WindowsBundledRunResult,
) -> @lepusa.RunReport {
  self.plan.bootstrap().run_plan().report(status=self.status)
}
