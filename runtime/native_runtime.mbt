///|
pub struct NativeRuntime {
  backend : NativeBackend
  host : RuntimeHost
  runner : NativeRunnerPlan
}

///|
pub fn NativeRuntime::new(
  backend : NativeBackend,
  host : RuntimeHost,
) -> Result[NativeRuntime, Array[String]] {
  match backend.runner_plan(host) {
    Ok(runner) => Ok({ backend, host, runner })
    Err(problems) => Err(problems)
  }
}

///|
pub fn NativeRuntime::backend(self : NativeRuntime) -> NativeBackend {
  self.backend
}

///|
pub fn NativeRuntime::host(self : NativeRuntime) -> RuntimeHost {
  self.host
}

///|
pub fn NativeRuntime::runner_plan(self : NativeRuntime) -> NativeRunnerPlan {
  self.runner
}

///|
pub fn NativeRuntime::service_supervisor_plan(
  self : NativeRuntime,
) -> NativeServiceSupervisorPlan {
  self.runner.service_supervisor_plan()
}

///|
pub fn NativeRuntime::service_supervisor_report(
  self : NativeRuntime,
) -> NativeServiceSupervisorReport {
  self.runner.service_supervisor_report()
}

///|
pub fn NativeRuntime::bootstrap_json(self : NativeRuntime) -> String {
  self.runner.bootstrap_json()
}

///|
pub fn NativeRuntime::resolve_asset_json(
  self : NativeRuntime,
  url : String,
) -> String {
  self.host.resolve_asset_json(url)
}

///|
pub fn NativeRuntime::dispatch_json(
  self : NativeRuntime,
  input : String,
) -> String {
  self.host.dispatch_json(input)
}

///|
pub async fn NativeRuntime::dispatch_json_async(
  self : NativeRuntime,
  input : String,
) -> String {
  self.host.dispatch_json_async(input)
}

///|
pub fn NativeRuntime::lifecycle_step_json(
  self : NativeRuntime,
  event : @lepusa.LifecycleEvent,
) -> Result[String, Array[String]] {
  match self.runner.lifecycle_step(event) {
    Ok(step) => Ok(step.to_json())
    Err(problems) => Err(problems)
  }
}
