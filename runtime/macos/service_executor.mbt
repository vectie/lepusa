///|
#borrow(name, command_packet)
extern "c" fn native_start_service(name : Bytes, command_packet : Bytes) -> Int = "lepusa_macos_start_service"

///|
#borrow(name)
extern "c" fn native_stop_service(name : Bytes) -> Int = "lepusa_macos_stop_service"

///|
#borrow(readiness_url)
extern "c" fn native_wait_until_ready(
  readiness_url : Bytes,
  timeout_ms : Int,
) -> Int = "lepusa_macos_wait_until_ready"

///|
pub fn service_executor() -> @runtime.NativeServiceExecutor {
  backend().service_executor(
    start_service=macos_start_service,
    wait_until_ready=macos_wait_until_ready,
    stop_service=macos_stop_service,
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
pub fn MacOSRunPlan::execute_app_will_exit(
  self : MacOSRunPlan,
) -> @runtime.NativeOperationExecutionReport {
  operation_executor().execute_app_will_exit(self.execution())
}

///|
fn macos_start_service(
  service : @lepusa.LocalService,
) -> @runtime.NativeServiceActionStatus {
  match
    native_start_service(
      @utf8.encode(service.name()),
      @runtime.native_service_command_packet(service.command()),
    ) {
    0 => NativeServiceActionStarted
    code =>
      NativeServiceActionFailed(
        "macOS service start failed for \{service.name()}: code \{code}",
      )
  }
}

///|
fn macos_wait_until_ready(
  service : @lepusa.LocalService,
) -> @runtime.NativeServiceActionStatus {
  match native_wait_until_ready(@utf8.encode(service.readiness_url()), 5000) {
    0 => NativeServiceActionReady
    code =>
      NativeServiceActionFailed(
        "macOS service readiness failed for \{service.name()}: code \{code}",
      )
  }
}

///|
fn macos_stop_service(
  service : @lepusa.LocalService,
) -> @runtime.NativeServiceActionStatus {
  match native_stop_service(@utf8.encode(service.name())) {
    0 => NativeServiceActionStopped
    1 =>
      NativeServiceActionSkipped(
        "macOS service stop skipped; process is not tracked: \{service.name()}",
      )
    code =>
      NativeServiceActionFailed(
        "macOS service stop failed for \{service.name()}: code \{code}",
      )
  }
}
