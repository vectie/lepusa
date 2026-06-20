///|
pub struct NativeLaunchSession {
  webviews : Array[NativeWebViewPlan]
  execution : NativeExecutionPlan
  bridge_scheduler : NativeBridgeScheduler
  service_supervisor : NativeServiceSupervisorPlan
} derive(Debug, Eq)

///|
pub fn NativeLaunchSession::new(
  webviews~ : Array[NativeWebViewPlan],
  execution~ : NativeExecutionPlan,
  bridge_scheduler~ : NativeBridgeScheduler,
  service_supervisor~ : NativeServiceSupervisorPlan,
) -> NativeLaunchSession {
  { webviews: webviews.copy(), execution, bridge_scheduler, service_supervisor }
}

///|
pub fn NativeLaunchSession::webviews(
  self : NativeLaunchSession,
) -> Array[NativeWebViewPlan] {
  self.webviews.copy()
}

///|
pub fn NativeLaunchSession::first_webview(
  self : NativeLaunchSession,
) -> Result[NativeWebViewPlan, String] {
  match self.webviews.get(0) {
    Some(webview) => Ok(webview)
    None => Err("native launch session requires at least one webview")
  }
}

///|
pub fn NativeLaunchSession::execution(
  self : NativeLaunchSession,
) -> NativeExecutionPlan {
  self.execution
}

///|
pub fn NativeLaunchSession::bridge_scheduler(
  self : NativeLaunchSession,
) -> NativeBridgeScheduler {
  self.bridge_scheduler
}

///|
pub fn NativeLaunchSession::async_bridge_executor(
  self : NativeLaunchSession,
) -> NativeBridgeAsyncExecutor {
  self.bridge_scheduler.async_executor()
}

///|
pub fn NativeLaunchSession::service_supervisor(
  self : NativeLaunchSession,
) -> NativeServiceSupervisorPlan {
  self.service_supervisor
}

///|
pub fn NativeLaunchSession::can_launch(self : NativeLaunchSession) -> Bool {
  self.bridge_scheduler.can_launch()
}

///|
pub fn NativeLaunchSession::launch_blocker(
  self : NativeLaunchSession,
  platform_name : String,
) -> String? {
  self.bridge_scheduler.launch_blocker(platform_name)
}

///|
pub fn NativeLaunchSession::to_json(self : NativeLaunchSession) -> String {
  [
    "{",
    "\"webviews\":[\{self.webviews.map(fn(webview) { webview.to_json() }).join(",")}],",
    "\"execution\":\{self.execution.to_json()},",
    "\"bridgeScheduler\":\{self.bridge_scheduler.to_json()},",
    "\"asyncBridgeExecutor\":\{self.async_bridge_executor().to_json()},",
    "\"serviceSupervisor\":\{self.service_supervisor.to_json()}",
    "}",
  ].join("")
}

///|
pub fn NativePreparedRunPlan::launch_session(
  self : NativePreparedRunPlan,
  bridge_mode? : NativeBridgeSchedulerMode = NativeBridgeSyncOnly,
) -> NativeLaunchSession {
  NativeLaunchSession::new(
    webviews=self.webviews(),
    execution=self.execution_plan(),
    bridge_scheduler=self.bridge_scheduler(mode=bridge_mode),
    service_supervisor=self.service_supervisor_plan(),
  )
}
