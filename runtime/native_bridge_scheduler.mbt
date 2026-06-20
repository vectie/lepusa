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
pub struct NativeBridgeAsyncExecutor {
  required : Bool
  available : Bool
  callback : String
  input_encoding : String
  output_encoding : String
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
pub fn NativeBridgeScheduler::async_executor(
  self : NativeBridgeScheduler,
) -> NativeBridgeAsyncExecutor {
  NativeBridgeAsyncExecutor::new(
    required=self.requires_async_dispatch(),
    available=self.supports_async_dispatch(),
  )
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
pub fn NativeBridgeAsyncExecutor::new(
  required~ : Bool,
  available~ : Bool,
) -> NativeBridgeAsyncExecutor {
  {
    required,
    available,
    callback: "NativeRuntime::bridge_async_dispatch_callback",
    input_encoding: "utf8-json-bridge-message",
    output_encoding: "utf8-javascript-callback-script",
  }
}

///|
pub fn NativeBridgeAsyncExecutor::required(
  self : NativeBridgeAsyncExecutor,
) -> Bool {
  self.required
}

///|
pub fn NativeBridgeAsyncExecutor::available(
  self : NativeBridgeAsyncExecutor,
) -> Bool {
  self.available
}

///|
pub fn NativeBridgeAsyncExecutor::callback(
  self : NativeBridgeAsyncExecutor,
) -> String {
  self.callback
}

///|
pub fn NativeBridgeAsyncExecutor::input_encoding(
  self : NativeBridgeAsyncExecutor,
) -> String {
  self.input_encoding
}

///|
pub fn NativeBridgeAsyncExecutor::output_encoding(
  self : NativeBridgeAsyncExecutor,
) -> String {
  self.output_encoding
}

///|
pub fn NativeBridgeAsyncExecutor::to_json(
  self : NativeBridgeAsyncExecutor,
) -> String {
  [
    "{",
    "\"required\":\{self.required.json_bool()},",
    "\"available\":\{self.available.json_bool()},",
    "\"callback\":\{self.callback.json_string()},",
    "\"inputEncoding\":\{self.input_encoding.json_string()},",
    "\"outputEncoding\":\{self.output_encoding.json_string()}",
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
