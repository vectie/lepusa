///|
pub(all) enum NativeRunStatus {
  NativeRunPrepared
  NativeRunLaunched
  NativeRunFailed(String)
  NativeRunUnsupported(String)
} derive(Debug, Eq)

///|
pub struct NativeRunReport {
  target : String
  backend_name : String
  webview_engine : String
  status : NativeRunStatus
  webview_count : Int
  first_window_url : String
  load_url : String
  startup_operation_count : Int
  lifecycle_step_count : Int
  bridge_sync_route_count : Int
  bridge_async_route_count : Int
} derive(Debug, Eq)

///|
pub fn NativeRunReport::from_runtime(
  target~ : String,
  runtime : NativeRuntime,
  status~ : NativeRunStatus,
  load_url? : String = "",
  bridge_sync_route_count? : Int = 0,
  bridge_async_route_count? : Int = 0,
) -> NativeRunReport {
  let plan = runtime.runner_plan()
  let first_window_url = match plan.webview_specs().get(0) {
    Some(webview) => webview.url()
    None => ""
  }
  {
    target,
    backend_name: plan.backend_name(),
    webview_engine: plan.webview_engine(),
    status,
    webview_count: plan.webview_specs().length(),
    first_window_url,
    load_url,
    startup_operation_count: plan.startup_operations().length(),
    lifecycle_step_count: plan.lifecycle_steps().length(),
    bridge_sync_route_count,
    bridge_async_route_count,
  }
}

///|
pub fn NativeRunStatus::name(self : NativeRunStatus) -> String {
  match self {
    NativeRunPrepared => "prepared"
    NativeRunLaunched => "launched"
    NativeRunFailed(_) => "failed"
    NativeRunUnsupported(_) => "unsupported"
  }
}

///|
pub fn NativeRunStatus::message(self : NativeRunStatus) -> String {
  match self {
    NativeRunFailed(message) | NativeRunUnsupported(message) => message
    _ => ""
  }
}

///|
pub fn NativeRunStatus::to_json(self : NativeRunStatus) -> String {
  let message = self.message()
  [
    "{",
    "\"name\":\{self.name().json_string()},",
    "\"message\":\{message.json_string()}",
    "}",
  ].join("")
}

///|
pub fn NativeRunReport::target(self : NativeRunReport) -> String {
  self.target
}

///|
pub fn NativeRunReport::backend_name(self : NativeRunReport) -> String {
  self.backend_name
}

///|
pub fn NativeRunReport::webview_engine(self : NativeRunReport) -> String {
  self.webview_engine
}

///|
pub fn NativeRunReport::status(self : NativeRunReport) -> NativeRunStatus {
  self.status
}

///|
pub fn NativeRunReport::webview_count(self : NativeRunReport) -> Int {
  self.webview_count
}

///|
pub fn NativeRunReport::first_window_url(self : NativeRunReport) -> String {
  self.first_window_url
}

///|
pub fn NativeRunReport::load_url(self : NativeRunReport) -> String {
  self.load_url
}

///|
pub fn NativeRunReport::startup_operation_count(self : NativeRunReport) -> Int {
  self.startup_operation_count
}

///|
pub fn NativeRunReport::lifecycle_step_count(self : NativeRunReport) -> Int {
  self.lifecycle_step_count
}

///|
pub fn NativeRunReport::bridge_sync_route_count(self : NativeRunReport) -> Int {
  self.bridge_sync_route_count
}

///|
pub fn NativeRunReport::bridge_async_route_count(self : NativeRunReport) -> Int {
  self.bridge_async_route_count
}

///|
pub fn NativeRunReport::to_json(self : NativeRunReport) -> String {
  [
    "{",
    "\"target\":\{self.target.json_string()},",
    "\"backend\":\{self.backend_name.json_string()},",
    "\"engine\":\{self.webview_engine.json_string()},",
    "\"status\":\{self.status.to_json()},",
    "\"webviews\":\{self.webview_count},",
    "\"firstWindowUrl\":\{self.first_window_url.json_string()},",
    "\"loadUrl\":\{self.load_url.json_string()},",
    "\"startupOperations\":\{self.startup_operation_count},",
    "\"lifecycleSteps\":\{self.lifecycle_step_count},",
    "\"bridgeSyncRoutes\":\{self.bridge_sync_route_count},",
    "\"bridgeAsyncRoutes\":\{self.bridge_async_route_count}",
    "}",
  ].join("")
}
