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
pub fn execute_service_startup(
  plan : @runtime.NativePreparedRunPlan,
) -> @runtime.NativeServiceSupervisorReport {
  service_executor().execute_startup(plan.service_supervisor_plan())
}

///|
pub fn execute_service_shutdown(
  plan : @runtime.NativePreparedRunPlan,
) -> @runtime.NativeServiceSupervisorReport {
  service_executor().execute_shutdown(plan.service_supervisor_plan())
}

///|
pub fn execute_app_will_exit(
  plan : @runtime.NativePreparedRunPlan,
) -> @runtime.NativeOperationExecutionReport {
  operation_executor().execute_app_will_exit(plan.execution_plan())
}

///|
pub fn execute_bundled_service_startup(
  plan : @bundled.BundledNativeRunPlan,
) -> @runtime.NativeServiceSupervisorReport {
  service_executor().execute_startup(plan.service_supervisor_plan())
}

///|
pub fn execute_bundled_service_shutdown(
  plan : @bundled.BundledNativeRunPlan,
) -> @runtime.NativeServiceSupervisorReport {
  service_executor().execute_shutdown(plan.service_supervisor_plan())
}

///|
pub fn execute_bundled_app_will_exit(
  plan : @bundled.BundledNativeRunPlan,
) -> Result[@runtime.NativeOperationExecutionReport, String] {
  match plan.native_execution_plan() {
    Ok(execution) => Ok(operation_executor().execute_app_will_exit(execution))
    Err(problem) => Err(problem)
  }
}

///|
fn linux_start_service(
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
