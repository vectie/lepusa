///|
pub fn service_executor() -> @runtime.NativeServiceExecutor {
  backend().service_executor(
    start_service=fn(service) { linux_service_action_skipped("start", service) },
    wait_until_ready=fn(service) {
      linux_service_action_skipped("readiness wait", service)
    },
    stop_service=fn(service) { linux_service_action_skipped("stop", service) },
  )
}

///|
pub fn LinuxRunPlan::execute_service_startup(
  self : LinuxRunPlan,
) -> @runtime.NativeServiceSupervisorReport {
  service_executor().execute_startup(self.service_supervisor_plan())
}

///|
pub fn LinuxRunPlan::execute_service_shutdown(
  self : LinuxRunPlan,
) -> @runtime.NativeServiceSupervisorReport {
  service_executor().execute_shutdown(self.service_supervisor_plan())
}

///|
pub fn LinuxBundledRunPlan::execute_service_startup(
  self : LinuxBundledRunPlan,
) -> @runtime.NativeServiceSupervisorReport {
  service_executor().execute_startup(self.service_supervisor_plan())
}

///|
pub fn LinuxBundledRunPlan::execute_service_shutdown(
  self : LinuxBundledRunPlan,
) -> @runtime.NativeServiceSupervisorReport {
  service_executor().execute_shutdown(self.service_supervisor_plan())
}

///|
fn linux_service_action_skipped(
  action : String,
  service : @lepusa.LocalService,
) -> @runtime.NativeServiceActionStatus {
  NativeServiceActionSkipped(
    "Linux service \{action} is waiting for native process supervisor: \{service.name()}",
  )
}
