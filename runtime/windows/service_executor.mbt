///|
pub fn service_executor() -> @runtime.NativeServiceExecutor {
  backend().service_executor(
    start_service=fn(service) {
      windows_service_action_skipped("start", service)
    },
    wait_until_ready=fn(service) {
      windows_service_action_skipped("readiness wait", service)
    },
    stop_service=fn(service) { windows_service_action_skipped("stop", service) },
  )
}

///|
pub fn WindowsRunPlan::execute_service_startup(
  self : WindowsRunPlan,
) -> @runtime.NativeServiceSupervisorReport {
  service_executor().execute_startup(self.service_supervisor_plan())
}

///|
pub fn WindowsRunPlan::execute_service_shutdown(
  self : WindowsRunPlan,
) -> @runtime.NativeServiceSupervisorReport {
  service_executor().execute_shutdown(self.service_supervisor_plan())
}

///|
pub fn WindowsBundledRunPlan::execute_service_startup(
  self : WindowsBundledRunPlan,
) -> @runtime.NativeServiceSupervisorReport {
  service_executor().execute_startup(self.service_supervisor_plan())
}

///|
pub fn WindowsBundledRunPlan::execute_service_shutdown(
  self : WindowsBundledRunPlan,
) -> @runtime.NativeServiceSupervisorReport {
  service_executor().execute_shutdown(self.service_supervisor_plan())
}

///|
fn windows_service_action_skipped(
  action : String,
  service : @lepusa.LocalService,
) -> @runtime.NativeServiceActionStatus {
  NativeServiceActionSkipped(
    "Windows service \{action} is waiting for native process supervisor: \{service.name()}",
  )
}
