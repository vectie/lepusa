///|
#borrow(name, command_packet)
extern "c" fn native_start_service(name : Bytes, command_packet : Bytes) -> Int = "lepusa_linux_start_service"

///|
#borrow(name)
extern "c" fn native_stop_service(name : Bytes) -> Int = "lepusa_linux_stop_service"

///|
#borrow(readiness_url)
extern "c" fn native_wait_until_ready(
  readiness_url : Bytes,
  timeout_ms : Int,
) -> Int = "lepusa_linux_wait_until_ready"

///|
pub fn service_executor() -> @runtime.NativeServiceExecutor {
  backend().service_executor(
    start_service=linux_start_service,
    wait_until_ready=linux_wait_until_ready,
    stop_service=linux_stop_service,
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
fn linux_start_service(
  service : @lepusa.LocalService,
) -> @runtime.NativeServiceActionStatus {
  match
    native_start_service(
      @utf8.encode(service.name()),
      linux_command_packet(service.command()),
    ) {
    0 => NativeServiceActionStarted
    code =>
      NativeServiceActionFailed(
        "Linux service start failed for \{service.name()}: code \{code}",
      )
  }
}

///|
fn linux_wait_until_ready(
  service : @lepusa.LocalService,
) -> @runtime.NativeServiceActionStatus {
  match native_wait_until_ready(@utf8.encode(service.readiness_url()), 5000) {
    0 => NativeServiceActionReady
    code =>
      NativeServiceActionFailed(
        "Linux service readiness failed for \{service.name()}: code \{code}",
      )
  }
}

///|
fn linux_stop_service(
  service : @lepusa.LocalService,
) -> @runtime.NativeServiceActionStatus {
  match native_stop_service(@utf8.encode(service.name())) {
    0 => NativeServiceActionStopped
    1 =>
      NativeServiceActionSkipped(
        "Linux service stop skipped; process is not tracked: \{service.name()}",
      )
    code =>
      NativeServiceActionFailed(
        "Linux service stop failed for \{service.name()}: code \{code}",
      )
  }
}

///|
fn linux_command_packet(command : Array[String]) -> Bytes {
  let chunks : Array[String] = []
  for part in command {
    chunks.push("\{@utf8.encode(part).length()}\n\{part}")
  }
  @utf8.encode(chunks.join(""))
}
