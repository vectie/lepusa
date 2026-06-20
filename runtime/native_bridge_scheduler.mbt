///|
pub(all) enum NativeBridgeSchedulerMode {
  NativeBridgeSyncOnly
  NativeBridgeAsyncCapable
} derive(Debug, Eq)

///|
pub struct NativeBridgeScheduler {
  sync_routes : Array[String]
  async_routes : Array[String]
  mode : NativeBridgeSchedulerMode
} derive(Debug, Eq)

///|
pub fn NativeBridgeScheduler::new(
  sync_routes~ : Array[String],
  async_routes~ : Array[String],
  mode? : NativeBridgeSchedulerMode = NativeBridgeSyncOnly,
) -> NativeBridgeScheduler {
  { sync_routes: sync_routes.copy(), async_routes: async_routes.copy(), mode }
}

///|
pub fn NativeBridgeScheduler::sync_routes(
  self : NativeBridgeScheduler,
) -> Array[String] {
  self.sync_routes.copy()
}

///|
pub fn NativeBridgeScheduler::async_routes(
  self : NativeBridgeScheduler,
) -> Array[String] {
  self.async_routes.copy()
}

///|
pub fn NativeBridgeScheduler::mode(
  self : NativeBridgeScheduler,
) -> NativeBridgeSchedulerMode {
  self.mode
}

///|
pub fn NativeBridgeScheduler::requires_async_dispatch(
  self : NativeBridgeScheduler,
) -> Bool {
  !self.async_routes.is_empty()
}

///|
pub fn NativeBridgeScheduler::supports_async_dispatch(
  self : NativeBridgeScheduler,
) -> Bool {
  self.mode is NativeBridgeAsyncCapable
}

///|
pub fn NativeBridgeScheduler::can_launch(self : NativeBridgeScheduler) -> Bool {
  !self.requires_async_dispatch() || self.supports_async_dispatch()
}

///|
pub fn NativeBridgeScheduler::launch_blocker(
  self : NativeBridgeScheduler,
  platform_name : String,
) -> String? {
  if self.can_launch() {
    None
  } else {
    Some(self.async_bridge_launch_message(platform_name))
  }
}

///|
pub fn NativeBridgeScheduler::async_bridge_launch_message(
  self : NativeBridgeScheduler,
  platform_name : String,
) -> String {
  let count = self.async_routes.length()
  "\{platform_name} launch requires native async bridge scheduling for \{count} async command route(s)"
}

///|
pub fn NativeBridgeScheduler::to_json(self : NativeBridgeScheduler) -> String {
  let mode = match self.mode {
    NativeBridgeSyncOnly => "sync-only"
    NativeBridgeAsyncCapable => "async-capable"
  }
  [
    "{",
    "\"mode\":\{mode.json_string()},",
    "\"syncRoutes\":[\{self.sync_routes.map(fn(route) { route.json_string() }).join(",")}],",
    "\"asyncRoutes\":[\{self.async_routes.map(fn(route) { route.json_string() }).join(",")}],",
    "\"requiresAsyncDispatch\":\{self.requires_async_dispatch().json_bool()},",
    "\"canLaunch\":\{self.can_launch().json_bool()}",
    "}",
  ].join("")
}

///|
pub fn NativeRunnerPlan::bridge_scheduler(
  self : NativeRunnerPlan,
  mode? : NativeBridgeSchedulerMode = NativeBridgeSyncOnly,
) -> NativeBridgeScheduler {
  NativeBridgeScheduler::new(
    sync_routes=self.bridge_sync_routes(),
    async_routes=self.bridge_async_routes(),
    mode~,
  )
}

///|
pub fn NativePreparedRunPlan::bridge_scheduler(
  self : NativePreparedRunPlan,
  mode? : NativeBridgeSchedulerMode = NativeBridgeSyncOnly,
) -> NativeBridgeScheduler {
  self.runner().bridge_scheduler(mode~)
}

///|
pub async fn NativeRuntime::dispatch_bridge_script_bytes_async(
  self : NativeRuntime,
  message : Bytes,
) -> Bytes {
  let input = @utf8.decode(message) catch { _ => "" }
  match self.dispatch_bridge_message(input) {
    Ok(dispatch) => @utf8.encode(dispatch.evaluation_script())
    Err(_) => @utf8.encode("")
  }
}

///|
pub fn NativeRuntime::bridge_async_dispatch_callback(
  self : NativeRuntime,
) -> async (Bytes) -> Bytes {
  message => self.dispatch_bridge_script_bytes_async(message)
}

///|
pub fn NativeRuntime::bridge_handoff_callback(
  self : NativeRuntime,
) -> (Bytes) -> Bytes {
  fn(message : Bytes) { self.bridge_handoff_script_bytes(message) }
}
