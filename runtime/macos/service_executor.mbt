///|
pub fn service_executor() -> @runtime.NativeServiceExecutor {
  backend().service_executor(
    start_service=fn(service) { macos_service_action_skipped("start", service) },
    wait_until_ready=fn(service) {
      macos_service_action_skipped("readiness wait", service)
    },
    stop_service=fn(service) { macos_service_action_skipped("stop", service) },
  )
}

///|
pub fn MacOSRunPlan::execute_service_startup(
  self : MacOSRunPlan,
) -> @runtime.NativeServiceSupervisorReport {
  service_executor().execute_startup(self.service_supervisor_plan())
}

///|
pub fn MacOSRunPlan::execute_service_shutdown(
  self : MacOSRunPlan,
) -> @runtime.NativeServiceSupervisorReport {
  service_executor().execute_shutdown(self.service_supervisor_plan())
}

///|
fn macos_service_action_skipped(
  action : String,
  service : @lepusa.LocalService,
) -> @runtime.NativeServiceActionStatus {
  NativeServiceActionSkipped(
    "macOS service \{action} is waiting for native process supervisor: \{service.name()}",
  )
}
