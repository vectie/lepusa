///|
pub fn NativeRuntime::run_report(
  self : NativeRuntime,
  target~ : String,
  status~ : @lepusa.RunStatus,
  load_url? : String = "",
  execution_report? : NativeOperationExecutionReport? = None,
  bridge_sync_routes? : Int = 0,
  bridge_async_routes? : Int = 0,
  target_can_launch? : Bool = true,
  target_launch_blocker? : String = "",
) -> @lepusa.RunReport {
  let plan = self.runner_plan()
  let services = plan.service_plan()
  let first_window_url = match plan.webview_specs().get(0) {
    Some(webview) => webview.url()
    None => ""
  }
  let first_window_title = match plan.webview_specs().get(0) {
    Some(webview) => webview.title()
    None => ""
  }
  let execution = match execution_report {
    Some(report) => report
    None =>
      NativeOperationExecutor::new().execute_startup(plan.execution_plan())
  }
  @lepusa.RunReport::new(
    target~,
    backend=plan.backend_name(),
    engine=plan.webview_engine(),
    status~,
    webviews=plan.webview_specs().length(),
    first_window_title~,
    first_window_url~,
    load_url~,
    bridge_url=plan.session().bridge_url(),
    local_services=services.services().length(),
    service_supervisor=services.requires_supervisor(),
    service_start_order=services.startup_service_names(),
    startup_operations=plan.startup_operations().length(),
    lifecycle_steps=plan.lifecycle_steps().length(),
    executable_operations=execution.operation_count(),
    executed_operations=execution.executed_count(),
    skipped_operations=execution.skipped_count(),
    failed_operations=execution.failed_count(),
    first_execution_failure=execution.first_failure_message().unwrap_or(""),
    bridge_sync_routes~,
    bridge_async_routes~,
    target_can_launch~,
    target_launch_blocker~,
  )
}
