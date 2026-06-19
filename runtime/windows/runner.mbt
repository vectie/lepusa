///|
pub(all) enum WindowsRunMode {
  WindowsDryRun
  WindowsOpenWindow
} derive(Debug, Eq)

///|
pub(all) enum WindowsRunStatus {
  WindowsPrepared
  WindowsLaunchUnsupported(String)
} derive(Debug, Eq)

///|
pub struct WindowsRunPlan {
  runner : @runtime.NativeRunnerPlan
} derive(Debug, Eq)

///|
pub struct WindowsRunResult {
  plan : WindowsRunPlan
  status : WindowsRunStatus
} derive(Debug, Eq)

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
          WindowsDryRun => WindowsPrepared
          WindowsOpenWindow =>
            WindowsLaunchUnsupported(
              "Windows WebView2 launch loop is not implemented",
            )
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
pub fn WindowsRunPlan::lifecycle_step_count(self : WindowsRunPlan) -> Int {
  self.runner.lifecycle_steps().length()
}

///|
pub fn WindowsRunResult::plan(self : WindowsRunResult) -> WindowsRunPlan {
  self.plan
}

///|
pub fn WindowsRunResult::status(self : WindowsRunResult) -> WindowsRunStatus {
  self.status
}
