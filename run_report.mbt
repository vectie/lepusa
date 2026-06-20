///|
pub(all) enum RunStatus {
  RunPrepared
  RunLaunched
  RunFailed(String)
  RunUnsupported(String)
} derive(Debug, Eq)

///|
pub struct RunReport {
  target : String
  backend : String
  engine : String
  status : RunStatus
  webviews : Int
  first_window_title : String
  first_window_url : String
  load_url : String
  bridge_url : String
  local_services : Int
  service_supervisor : Bool
  service_start_order : Array[String]
  startup_operations : Int
  lifecycle_steps : Int
  executable_operations : Int
  executed_operations : Int
  skipped_operations : Int
  failed_operations : Int
  first_execution_failure : String
  bridge_sync_routes : Int
  bridge_async_routes : Int
  target_can_launch : Bool
  target_launch_blocker : String
} derive(Debug, Eq)

///|
pub fn RunReport::new(
  target~ : String,
  backend~ : String,
  engine~ : String,
  status~ : RunStatus,
  webviews~ : Int,
  first_window_title? : String = "",
  first_window_url? : String = "",
  load_url? : String = "",
  bridge_url? : String = "",
  local_services? : Int = 0,
  service_supervisor? : Bool = false,
  service_start_order? : Array[String] = [],
  startup_operations? : Int = 0,
  lifecycle_steps? : Int = 0,
  executable_operations? : Int = 0,
  executed_operations? : Int = 0,
  skipped_operations? : Int = 0,
  failed_operations? : Int = 0,
  first_execution_failure? : String = "",
  bridge_sync_routes? : Int = 0,
  bridge_async_routes? : Int = 0,
  target_can_launch? : Bool = true,
  target_launch_blocker? : String = "",
) -> RunReport {
  {
    target,
    backend,
    engine,
    status,
    webviews,
    first_window_title,
    first_window_url,
    load_url,
    bridge_url,
    local_services,
    service_supervisor,
    service_start_order: service_start_order.copy(),
    startup_operations,
    lifecycle_steps,
    executable_operations,
    executed_operations,
    skipped_operations,
    failed_operations,
    first_execution_failure,
    bridge_sync_routes,
    bridge_async_routes,
    target_can_launch,
    target_launch_blocker,
  }
}

///|
pub fn RunStatus::name(self : RunStatus) -> String {
  match self {
    RunPrepared => "prepared"
    RunLaunched => "launched"
    RunFailed(_) => "failed"
    RunUnsupported(_) => "unsupported"
  }
}

///|
pub fn RunStatus::message(self : RunStatus) -> String {
  match self {
    RunFailed(message) | RunUnsupported(message) => message
    _ => ""
  }
}

///|
pub fn RunStatus::to_json(self : RunStatus) -> String {
  [
    "{",
    "\"name\":\{self.name().json_string()},",
    "\"message\":\{self.message().json_string()}",
    "}",
  ].join("")
}

///|
pub fn RunReport::target(self : RunReport) -> String {
  self.target
}

///|
pub fn RunReport::backend(self : RunReport) -> String {
  self.backend
}

///|
pub fn RunReport::engine(self : RunReport) -> String {
  self.engine
}

///|
pub fn RunReport::status(self : RunReport) -> RunStatus {
  self.status
}

///|
pub fn RunReport::webviews(self : RunReport) -> Int {
  self.webviews
}

///|
pub fn RunReport::first_window_url(self : RunReport) -> String {
  self.first_window_url
}

///|
pub fn RunReport::first_window_title(self : RunReport) -> String {
  self.first_window_title
}

///|
pub fn RunReport::load_url(self : RunReport) -> String {
  self.load_url
}

///|
pub fn RunReport::bridge_url(self : RunReport) -> String {
  self.bridge_url
}

///|
pub fn RunReport::local_services(self : RunReport) -> Int {
  self.local_services
}

///|
pub fn RunReport::service_supervisor(self : RunReport) -> Bool {
  self.service_supervisor
}

///|
pub fn RunReport::service_start_order(self : RunReport) -> Array[String] {
  self.service_start_order.copy()
}

///|
pub fn RunReport::startup_operations(self : RunReport) -> Int {
  self.startup_operations
}

///|
pub fn RunReport::lifecycle_steps(self : RunReport) -> Int {
  self.lifecycle_steps
}

///|
pub fn RunReport::executable_operations(self : RunReport) -> Int {
  self.executable_operations
}

///|
pub fn RunReport::executed_operations(self : RunReport) -> Int {
  self.executed_operations
}

///|
pub fn RunReport::skipped_operations(self : RunReport) -> Int {
  self.skipped_operations
}

///|
pub fn RunReport::failed_operations(self : RunReport) -> Int {
  self.failed_operations
}

///|
pub fn RunReport::first_execution_failure(self : RunReport) -> String {
  self.first_execution_failure
}

///|
pub fn RunReport::bridge_sync_routes(self : RunReport) -> Int {
  self.bridge_sync_routes
}

///|
pub fn RunReport::bridge_async_routes(self : RunReport) -> Int {
  self.bridge_async_routes
}

///|
pub fn RunReport::target_can_launch(self : RunReport) -> Bool {
  self.target_can_launch
}

///|
pub fn RunReport::target_launch_blocker(self : RunReport) -> String {
  self.target_launch_blocker
}

///|
pub fn RunReport::to_json(self : RunReport) -> String {
  [
    "{",
    "\"target\":\{self.target.json_string()},",
    "\"backend\":\{self.backend.json_string()},",
    "\"engine\":\{self.engine.json_string()},",
    "\"status\":\{self.status.to_json()},",
    "\"webviews\":\{self.webviews},",
    "\"firstWindowTitle\":\{self.first_window_title.json_string()},",
    "\"firstWindowUrl\":\{self.first_window_url.json_string()},",
    "\"loadUrl\":\{self.load_url.json_string()},",
    "\"bridgeUrl\":\{self.bridge_url.json_string()},",
    "\"localServices\":\{self.local_services},",
    "\"serviceSupervisor\":\{self.service_supervisor},",
    "\"serviceStartOrder\":[\{self.service_start_order.map(fn(name) { name.json_string() }).join(",")}],",
    "\"startupOperations\":\{self.startup_operations},",
    "\"lifecycleSteps\":\{self.lifecycle_steps},",
    "\"executableOperations\":\{self.executable_operations},",
    "\"executedOperations\":\{self.executed_operations},",
    "\"skippedOperations\":\{self.skipped_operations},",
    "\"failedOperations\":\{self.failed_operations},",
    "\"firstExecutionFailure\":\{self.first_execution_failure.json_string()},",
    "\"bridgeSyncRoutes\":\{self.bridge_sync_routes},",
    "\"bridgeAsyncRoutes\":\{self.bridge_async_routes},",
    "\"targetCanLaunch\":\{self.target_can_launch.json_bool()},",
    "\"targetLaunchBlocker\":\{self.target_launch_blocker.json_string()}",
    "}",
  ].join("")
}
