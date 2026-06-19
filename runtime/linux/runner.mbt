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
pub struct LinuxBundledRunPlan {
  bootstrap : @bundled.BundledBootstrapPlan
} derive(Debug)

///|
pub struct LinuxBundledRunResult {
  plan : LinuxBundledRunPlan
  status : @lepusa.RunStatus
} derive(Debug)

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
pub fn prepare_bundled_run(
  manifest : @bundled.BundledRuntimeManifest,
) -> Result[LinuxBundledRunPlan, Array[String]] {
  if manifest.target() != "linux" {
    return Err(["Linux bundled run requires target linux: \{manifest.target()}"])
  }
  match manifest.bootstrap_plan() {
    Ok(bootstrap) => Ok({ bootstrap, })
    Err(problem) => Err([problem])
  }
}

///|
pub fn run_bundled(
  manifest : @bundled.BundledRuntimeManifest,
  mode? : LinuxRunMode = LinuxDryRun,
) -> Result[LinuxBundledRunResult, Array[String]] {
  match prepare_bundled_run(manifest) {
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
pub fn launch_bundled(
  manifest : @bundled.BundledRuntimeManifest,
) -> Result[LinuxBundledRunResult, Array[String]] {
  run_bundled(manifest, mode=LinuxOpenWindow)
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

///|
pub fn LinuxBundledRunPlan::bootstrap(
  self : LinuxBundledRunPlan,
) -> @bundled.BundledBootstrapPlan {
  self.bootstrap
}

///|
pub fn LinuxBundledRunPlan::bootstrap_json(
  self : LinuxBundledRunPlan,
) -> String {
  self.bootstrap.to_json()
}

///|
pub fn LinuxBundledRunPlan::webview_count(self : LinuxBundledRunPlan) -> Int {
  self.bootstrap.run_plan().webviews().length()
}

///|
pub fn LinuxBundledRunPlan::first_webview_url(
  self : LinuxBundledRunPlan,
) -> String {
  match self.bootstrap.run_plan().first_webview() {
    Some(webview) => webview.url()
    None => ""
  }
}

///|
pub fn LinuxBundledRunPlan::startup_operation_count(
  self : LinuxBundledRunPlan,
) -> Int {
  self.bootstrap.startup_operations().length()
}

///|
pub fn LinuxBundledRunPlan::lifecycle_step_count(
  self : LinuxBundledRunPlan,
) -> Int {
  self.bootstrap.lifecycle_operations().length()
}

///|
pub fn LinuxBundledRunResult::plan(
  self : LinuxBundledRunResult,
) -> LinuxBundledRunPlan {
  self.plan
}

///|
pub fn LinuxBundledRunResult::status(
  self : LinuxBundledRunResult,
) -> @lepusa.RunStatus {
  self.status
}

///|
pub fn LinuxBundledRunResult::report(
  self : LinuxBundledRunResult,
) -> @lepusa.RunReport {
  self.plan.bootstrap().run_plan().report(status=self.status)
}
