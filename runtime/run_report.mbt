///|
pub fn NativeRuntime::run_report(
  self : NativeRuntime,
  target~ : String,
  status~ : @lepusa.RunStatus,
  load_url? : String = "",
  bridge_sync_routes? : Int = 0,
  bridge_async_routes? : Int = 0,
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
    bridge_sync_routes~,
    bridge_async_routes~,
  )
}
