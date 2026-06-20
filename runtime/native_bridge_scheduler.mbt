///|
pub(all) enum NativeBridgeSchedulerMode {
  NativeBridgeSyncOnly
  NativeBridgeAsyncCapable
} derive(Debug, Eq)

///|
pub(all) enum NativeBridgeDrainStrategy {
  NativeBridgeDrainUnavailable
  NativeBridgeDrainEventLoop
} derive(Debug, Eq)

///|
pub fn NativeBridgeSchedulerMode::name(
  self : NativeBridgeSchedulerMode,
) -> String {
  match self {
    NativeBridgeSyncOnly => "sync-only"
    NativeBridgeAsyncCapable => "async-capable"
  }
}

///|
pub fn NativeBridgeDrainStrategy::name(
  self : NativeBridgeDrainStrategy,
) -> String {
  match self {
    NativeBridgeDrainUnavailable => "unavailable"
    NativeBridgeDrainEventLoop => "event-loop"
  }
}

///|
pub fn NativeBridgeSchedulerMode::drain_strategy(
  self : NativeBridgeSchedulerMode,
) -> NativeBridgeDrainStrategy {
  match self {
    NativeBridgeSyncOnly => NativeBridgeDrainUnavailable
    NativeBridgeAsyncCapable => NativeBridgeDrainEventLoop
  }
}

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
pub struct NativeBridgeLoopContract {
  required : Bool
  available : Bool
  drain_strategy : NativeBridgeDrainStrategy
  adapter : String
  handoff_callback : String
  handoff_packet_callback : String
  receive_message : String
  receive_window_message : String
  drain_window : String
  drain_window_scripts : String
  result_type : String
  delivery_type : String
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
pub fn NativeBridgeScheduler::drain_strategy(
  self : NativeBridgeScheduler,
) -> NativeBridgeDrainStrategy {
  self.mode.drain_strategy()
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
pub fn NativeBridgeScheduler::bridge_loop_contract(
  self : NativeBridgeScheduler,
) -> NativeBridgeLoopContract {
  NativeBridgeLoopContract::new(
    required=self.requires_async_dispatch(),
    available=self.supports_async_dispatch(),
    drain_strategy=self.drain_strategy(),
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
  [
    "{",
    "\"mode\":\{self.mode.name().json_string()},",
    "\"syncRoutes\":[\{self.sync_routes.map(fn(route) { route.json_string() }).join(",")}],",
    "\"asyncRoutes\":[\{self.async_routes.map(fn(route) { route.json_string() }).join(",")}],",
    "\"drainStrategy\":\{self.drain_strategy().name().json_string()},",
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
pub fn NativeBridgeLoopContract::new(
  required~ : Bool,
  available~ : Bool,
  drain_strategy? : NativeBridgeDrainStrategy = if available {
    NativeBridgeDrainEventLoop
  } else {
    NativeBridgeDrainUnavailable
  },
) -> NativeBridgeLoopContract {
  {
    required,
    available,
    drain_strategy,
    adapter: "NativeBridgeLoopAdapter|BundledBridgeLoopAdapter",
    handoff_callback: "bridge_loop_adapter().handoff_callback",
    handoff_packet_callback: "bridge_loop_adapter().handoff_packet_callback",
    receive_message: "bridge_loop_adapter().receive_message",
    receive_window_message: "bridge_loop_adapter().receive_window_message",
    drain_window: "bridge_loop_adapter().drain_window",
    drain_window_scripts: "bridge_loop_adapter().callbacks(window).drain_window_scripts",
    result_type: "NativeBridgeLoopResult|BundledBridgeLoopResult",
    delivery_type: "NativeBridgeLoopDelivery|BundledBridgeLoopDelivery",
    input_encoding: "utf8-json-bridge-message",
    output_encoding: "json-bridge-loop-delivery",
  }
}

///|
pub fn NativeBridgeLoopContract::required(
  self : NativeBridgeLoopContract,
) -> Bool {
  self.required
}

///|
pub fn NativeBridgeLoopContract::available(
  self : NativeBridgeLoopContract,
) -> Bool {
  self.available
}

///|
pub fn NativeBridgeLoopContract::drain_strategy(
  self : NativeBridgeLoopContract,
) -> NativeBridgeDrainStrategy {
  self.drain_strategy
}

///|
pub fn NativeBridgeLoopContract::adapter(
  self : NativeBridgeLoopContract,
) -> String {
  self.adapter
}

///|
pub fn NativeBridgeLoopContract::handoff_callback(
  self : NativeBridgeLoopContract,
) -> String {
  self.handoff_callback
}

///|
pub fn NativeBridgeLoopContract::handoff_packet_callback(
  self : NativeBridgeLoopContract,
) -> String {
  self.handoff_packet_callback
}

///|
pub fn NativeBridgeLoopContract::receive_message(
  self : NativeBridgeLoopContract,
) -> String {
  self.receive_message
}

///|
pub fn NativeBridgeLoopContract::receive_window_message(
  self : NativeBridgeLoopContract,
) -> String {
  self.receive_window_message
}

///|
pub fn NativeBridgeLoopContract::drain_window(
  self : NativeBridgeLoopContract,
) -> String {
  self.drain_window
}

///|
pub fn NativeBridgeLoopContract::drain_window_scripts(
  self : NativeBridgeLoopContract,
) -> String {
  self.drain_window_scripts
}

///|
pub fn NativeBridgeLoopContract::result_type(
  self : NativeBridgeLoopContract,
) -> String {
  self.result_type
}

///|
pub fn NativeBridgeLoopContract::delivery_type(
  self : NativeBridgeLoopContract,
) -> String {
  self.delivery_type
}

///|
pub fn NativeBridgeLoopContract::input_encoding(
  self : NativeBridgeLoopContract,
) -> String {
  self.input_encoding
}

///|
pub fn NativeBridgeLoopContract::output_encoding(
  self : NativeBridgeLoopContract,
) -> String {
  self.output_encoding
}

///|
pub fn NativeBridgeLoopContract::to_json(
  self : NativeBridgeLoopContract,
) -> String {
  [
    "{",
    "\"required\":\{self.required.json_bool()},",
    "\"available\":\{self.available.json_bool()},",
    "\"drainStrategy\":\{self.drain_strategy.name().json_string()},",
    "\"adapter\":\{self.adapter.json_string()},",
    "\"handoffCallback\":\{self.handoff_callback.json_string()},",
    "\"handoffPacketCallback\":\{self.handoff_packet_callback.json_string()},",
    "\"receiveMessage\":\{self.receive_message.json_string()},",
    "\"receiveWindowMessage\":\{self.receive_window_message.json_string()},",
    "\"drainWindow\":\{self.drain_window.json_string()},",
    "\"drainWindowScripts\":\{self.drain_window_scripts.json_string()},",
    "\"resultType\":\{self.result_type.json_string()},",
    "\"deliveryType\":\{self.delivery_type.json_string()},",
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
