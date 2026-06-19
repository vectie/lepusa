///|
pub(all) enum LinuxRunMode {
  LinuxDryRun
  LinuxOpenWindow
} derive(Debug, Eq)

///|
pub struct LinuxRunPlan {
  runner : @runtime.NativeRunnerPlan
} derive(Debug, Eq)

///|
pub struct LinuxRunResult {
  plan : LinuxRunPlan
  status : @lepusa.RunStatus
} derive(Debug, Eq)

///|
pub fn prepare_run(
  runtime : @runtime.NativeRuntime,
) -> Result[LinuxRunPlan, Array[String]] {
  Ok({ runner: runtime.runner_plan() })
}

///|
pub fn run(
  runtime : @runtime.NativeRuntime,
  mode? : LinuxRunMode = LinuxDryRun,
) -> Result[LinuxRunResult, Array[String]] {
  match prepare_run(runtime) {
    Err(problems) => Err(problems)
    Ok(plan) =>
      Ok({
        plan,
        status: match mode {
          LinuxDryRun => RunPrepared
          LinuxOpenWindow =>
            RunUnsupported("Linux WebKitGTK launch loop is not implemented")
        },
      })
  }
}

///|
pub fn launch(
  runtime : @runtime.NativeRuntime,
) -> Result[LinuxRunResult, Array[String]] {
  run(runtime, mode=LinuxOpenWindow)
}

///|
pub fn LinuxRunPlan::runner(self : LinuxRunPlan) -> @runtime.NativeRunnerPlan {
  self.runner
}

///|
pub fn LinuxRunPlan::webview_count(self : LinuxRunPlan) -> Int {
  self.runner.webview_specs().length()
}

///|
pub fn LinuxRunPlan::first_webview_url(self : LinuxRunPlan) -> String {
  match self.runner.webview_specs().get(0) {
    Some(webview) => webview.url()
    None => ""
  }
}

///|
pub fn LinuxRunPlan::startup_operation_count(self : LinuxRunPlan) -> Int {
  self.runner.startup_operations().length()
}

///|
pub fn LinuxRunPlan::lifecycle_step_count(self : LinuxRunPlan) -> Int {
  self.runner.lifecycle_steps().length()
}

///|
pub fn LinuxRunResult::plan(self : LinuxRunResult) -> LinuxRunPlan {
  self.plan
}

///|
pub fn LinuxRunResult::status(self : LinuxRunResult) -> @lepusa.RunStatus {
  self.status
}
