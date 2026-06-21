///|
pub struct BundledBridgeMessage {
  window_label : String
  response_hook : String
  message : String
} derive(Debug, Eq)

///|
pub struct BundledBridgeDispatch {
  window_label : String
  response_hook : String
  message : String
  response_json : String
  evaluation_script : String
  extra_operations : Array[@runtime.NativeExecutableOperation]
} derive(Debug, Eq)

///|
pub struct BundledBridgeDispatchTask {
  message : BundledBridgeMessage
  route : String
  mode : @runtime.NativeBridgeDispatchMode
} derive(Debug, Eq)

///|
pub struct BundledBridgeHandoff {
  task : BundledBridgeDispatchTask
  immediate_dispatch : BundledBridgeDispatch?
} derive(Debug, Eq)

///|
pub struct BundledBridgeCompletion {
  task : BundledBridgeDispatchTask
  dispatch : BundledBridgeDispatch
} derive(Debug, Eq)

///|
pub struct BundledBridgeDrainResult {
  pending_before : Int
  pending_after : Int
  completions : Array[BundledBridgeCompletion]
  evaluation_scripts : Array[String]
  operations : Array[@runtime.NativeExecutableOperation]
} derive(Debug, Eq)

///|
pub struct BundledBridgeWorkQueue {
  tasks : Array[BundledBridgeDispatchTask]
} derive(Debug, Eq)

///|
pub struct BundledBridgeLoopAdapter {
  runtime : BundledRuntime
  queue : BundledBridgeWorkQueue
}

///|
pub struct BundledBridgeLoopCallbacks {
  window_label : String
  handoff_callback : (Bytes) -> Bytes
  handoff_packet_callback : (Bytes) -> Bytes
  drain_window_callback : async () -> BundledBridgeLoopDelivery
}

///|
pub struct BundledBridgeLoopResult {
  immediate_script : String
  completions : Array[BundledBridgeCompletion]
} derive(Debug, Eq)

///|
pub struct BundledBridgeLoopDelivery {
  window_label : String
  result : BundledBridgeLoopResult
  evaluation_plan : @runtime.NativeBridgeLoopEvaluationPlan
} derive(Debug, Eq)

///|
pub fn BundledRuntimeManifest::prepare_bridge_message(
  self : BundledRuntimeManifest,
  message : String,
  window_label? : String = "",
) -> Result[BundledBridgeMessage, Array[String]] {
  let resolved_window_label = bundled_bridge_window_label_from_message(
    message,
    window_label~,
  )
  match self.bridge_response_hook(window_label=resolved_window_label) {
    Ok((window_label, response_hook)) =>
      Ok({ window_label, response_hook, message })
    Err(problem) => Err([problem])
  }
}

///|
pub fn BundledRuntime::prepare_bridge_message(
  self : BundledRuntime,
  message : String,
  window_label? : String = "",
) -> Result[BundledBridgeMessage, Array[String]] {
  self.manifest.prepare_bridge_message(message, window_label~)
}

///|
pub fn BundledRuntimeManifest::bridge_dispatch_task(
  self : BundledRuntimeManifest,
  message : String,
  window_label? : String = "",
) -> Result[BundledBridgeDispatchTask, Array[String]] {
  BundledRuntime::new(self).bridge_dispatch_task(message, window_label~)
}

///|
pub fn BundledRuntimeManifest::bridge_handoff(
  self : BundledRuntimeManifest,
  message : String,
  window_label? : String = "",
) -> Result[BundledBridgeHandoff, Array[String]] {
  BundledRuntime::new(self).bridge_handoff(message, window_label~)
}

///|
pub fn BundledRuntime::bridge_dispatch_task(
  self : BundledRuntime,
  message : String,
  window_label? : String = "",
) -> Result[BundledBridgeDispatchTask, Array[String]] {
  match self.prepare_bridge_message(message, window_label~) {
    Err(problems) => Err(problems)
    Ok(prepared) =>
      match @runtime.decode_invoke_request_json(message) {
        Err(problem) => Err([problem])
        Ok(request) => {
          let route = request.route()
          let mode = if self.manifest.registered_async_routes().contains(route) {
            @runtime.NativeBridgeDispatchAsync
          } else {
            NativeBridgeDispatchSync
          }
          Ok({ message: prepared, route, mode })
        }
      }
  }
}

///|
pub fn BundledRuntime::bridge_handoff(
  self : BundledRuntime,
  message : String,
  window_label? : String = "",
) -> Result[BundledBridgeHandoff, Array[String]] {
  match self.bridge_dispatch_task(message, window_label~) {
    Err(problems) => Err(problems)
    Ok(task) => {
      let immediate_dispatch = if task.requires_async_dispatch() {
        None
      } else {
        Some(task.dispatch_sync(self))
      }
      Ok({ task, immediate_dispatch })
    }
  }
}

///|
pub fn BundledRuntimeManifest::bridge_response_hook(
  self : BundledRuntimeManifest,
  window_label? : String = "",
) -> Result[(String, String), String] {
  match self.webviews() {
    Err(problem) => Err(problem)
    Ok(webviews) => {
      if window_label != "" {
        for webview in webviews {
          if webview.label() == window_label {
            return Ok((webview.label(), "\{webview.native_hook()}Response"))
          }
        }
        return Err("bundled bridge window not found: \{window_label}")
      }
      match webviews.get(0) {
        Some(webview) =>
          Ok((webview.label(), "\{webview.native_hook()}Response"))
        None => Err("bundled bridge dispatch requires at least one webview")
      }
    }
  }
}

///|
pub fn BundledRuntimeManifest::dispatch_bridge_message_sync(
  self : BundledRuntimeManifest,
  message : String,
  window_label? : String = "",
) -> Result[BundledBridgeDispatch, Array[String]] {
  BundledRuntime::new(self).dispatch_bridge_message_sync(message, window_label~)
}

///|
pub fn BundledRuntime::dispatch_bridge_message_sync(
  self : BundledRuntime,
  message : String,
  window_label? : String = "",
) -> Result[BundledBridgeDispatch, Array[String]] {
  match self.prepare_bridge_message(message, window_label~) {
    Err(problems) => Err(problems)
    Ok(prepared) => Ok(prepared.dispatch_sync(self))
  }
}

///|
pub fn BundledRuntime::dispatch_bridge_script_bytes(
  self : BundledRuntime,
  message : Bytes,
) -> Bytes {
  let input = @utf8.decode(message) catch { _ => "" }
  match self.dispatch_bridge_message_sync(input) {
    Ok(dispatch) => @utf8.encode(dispatch.evaluation_script())
    Err(_) => @utf8.encode("")
  }
}

///|
pub fn BundledRuntime::bridge_handoff_script_bytes(
  self : BundledRuntime,
  message : Bytes,
) -> Bytes {
  let input = @utf8.decode(message) catch { _ => "" }
  match self.bridge_handoff(input) {
    Ok(handoff) =>
      match handoff.immediate_script() {
        Some(script) => @utf8.encode(script)
        None => @utf8.encode("")
      }
    Err(_) => @utf8.encode("")
  }
}

///|
pub async fn BundledRuntime::dispatch_bridge_script_bytes_async(
  self : BundledRuntime,
  message : Bytes,
) -> Bytes {
  let input = @utf8.decode(message) catch { _ => "" }
  match self.dispatch_bridge_message(input) {
    Ok(dispatch) => @utf8.encode(dispatch.evaluation_script())
    Err(_) => @utf8.encode("")
  }
}

///|
pub async fn BundledRuntimeManifest::dispatch_bridge_message(
  self : BundledRuntimeManifest,
  message : String,
  window_label? : String = "",
) -> Result[BundledBridgeDispatch, Array[String]] {
  BundledRuntime::new(self).dispatch_bridge_message(message, window_label~)
}

///|
pub async fn BundledRuntime::dispatch_bridge_message(
  self : BundledRuntime,
  message : String,
  window_label? : String = "",
) -> Result[BundledBridgeDispatch, Array[String]] {
  match self.prepare_bridge_message(message, window_label~) {
    Err(problems) => Err(problems)
    Ok(prepared) => Ok(prepared.dispatch(self))
  }
}

///|
pub fn BundledBridgeMessage::dispatch_sync(
  self : BundledBridgeMessage,
  runtime : BundledRuntime,
) -> BundledBridgeDispatch {
  match @runtime.decode_invoke_request_json(self.message) {
    Ok(request) => {
      let (response, operations) = runtime.dispatch_with_operations(request)
      self.to_dispatch_with_operations(
        @runtime.encode_invoke_response_json(response),
        operations,
      )
    }
    Err(problem) =>
      self.to_dispatch(
        @runtime.encode_invoke_response_json(
          @lepusa.InvokeResponse::invalid_request("", problem),
        ),
      )
  }
}

///|
pub async fn BundledBridgeMessage::dispatch(
  self : BundledBridgeMessage,
  runtime : BundledRuntime,
) -> BundledBridgeDispatch {
  match @runtime.decode_invoke_request_json(self.message) {
    Ok(request) => {
      let (response, operations) = runtime.dispatch_with_operations_async(
        request,
      )
      self.to_dispatch_with_operations(
        @runtime.encode_invoke_response_json(response),
        operations,
      )
    }
    Err(problem) =>
      self.to_dispatch(
        @runtime.encode_invoke_response_json(
          @lepusa.InvokeResponse::invalid_request("", problem),
        ),
      )
  }
}

///|
fn BundledBridgeMessage::to_dispatch(
  self : BundledBridgeMessage,
  response_json : String,
) -> BundledBridgeDispatch {
  self.to_dispatch_with_operations(response_json, [])
}

///|
fn BundledBridgeMessage::to_dispatch_with_operations(
  self : BundledBridgeMessage,
  response_json : String,
  extra_operations : Array[@runtime.NativeExecutableOperation],
) -> BundledBridgeDispatch {
  {
    window_label: self.window_label,
    response_hook: self.response_hook,
    message: self.message,
    response_json,
    evaluation_script: @runtime.native_bridge_response_script(
      self.response_hook,
      response_json,
    ),
    extra_operations,
  }
}

///|
pub fn BundledBridgeMessage::window_label(
  self : BundledBridgeMessage,
) -> String {
  self.window_label
}

///|
pub fn BundledBridgeMessage::response_hook(
  self : BundledBridgeMessage,
) -> String {
  self.response_hook
}

///|
pub fn BundledBridgeMessage::message(self : BundledBridgeMessage) -> String {
  self.message
}

///|
pub fn BundledBridgeDispatchTask::message(
  self : BundledBridgeDispatchTask,
) -> BundledBridgeMessage {
  self.message
}

///|
pub fn BundledBridgeDispatchTask::window_label(
  self : BundledBridgeDispatchTask,
) -> String {
  self.message.window_label()
}

///|
pub fn BundledBridgeDispatchTask::response_hook(
  self : BundledBridgeDispatchTask,
) -> String {
  self.message.response_hook()
}

///|
pub fn BundledBridgeDispatchTask::route(
  self : BundledBridgeDispatchTask,
) -> String {
  self.route
}

///|
pub fn BundledBridgeDispatchTask::mode(
  self : BundledBridgeDispatchTask,
) -> @runtime.NativeBridgeDispatchMode {
  self.mode
}

///|
pub fn BundledBridgeDispatchTask::requires_async_dispatch(
  self : BundledBridgeDispatchTask,
) -> Bool {
  self.mode == NativeBridgeDispatchAsync
}

///|
pub async fn BundledBridgeDispatchTask::dispatch(
  self : BundledBridgeDispatchTask,
  runtime : BundledRuntime,
) -> BundledBridgeDispatch {
  match self.mode {
    NativeBridgeDispatchSync => self.message.dispatch_sync(runtime)
    NativeBridgeDispatchAsync => self.message.dispatch(runtime)
  }
}

///|
pub async fn BundledBridgeDispatchTask::complete(
  self : BundledBridgeDispatchTask,
  runtime : BundledRuntime,
) -> BundledBridgeCompletion {
  { task: self, dispatch: self.dispatch(runtime) }
}

///|
fn BundledBridgeDispatchTask::dispatch_sync(
  self : BundledBridgeDispatchTask,
  runtime : BundledRuntime,
) -> BundledBridgeDispatch {
  self.message.dispatch_sync(runtime)
}

///|
pub fn BundledBridgeDispatchTask::to_json(
  self : BundledBridgeDispatchTask,
) -> String {
  [
    "{",
    "\"windowLabel\":\{self.window_label().json_string()},",
    "\"responseHook\":\{self.response_hook().json_string()},",
    "\"message\":\{self.message.message().json_string()},",
    "\"route\":\{self.route.json_string()},",
    "\"mode\":\{self.mode.name().json_string()},",
    "\"requiresAsyncDispatch\":\{self.requires_async_dispatch().json_bool()}",
    "}",
  ].join("")
}

///|
pub fn BundledBridgeHandoff::task(
  self : BundledBridgeHandoff,
) -> BundledBridgeDispatchTask {
  self.task
}

///|
pub fn BundledBridgeHandoff::mode(
  self : BundledBridgeHandoff,
) -> @runtime.NativeBridgeDispatchMode {
  self.task.mode()
}

///|
pub fn BundledBridgeHandoff::requires_async_dispatch(
  self : BundledBridgeHandoff,
) -> Bool {
  self.task.requires_async_dispatch()
}

///|
pub fn BundledBridgeHandoff::immediate_dispatch(
  self : BundledBridgeHandoff,
) -> BundledBridgeDispatch? {
  self.immediate_dispatch
}

///|
pub fn BundledBridgeHandoff::immediate_script(
  self : BundledBridgeHandoff,
) -> String? {
  match self.immediate_dispatch {
    Some(dispatch) => Some(dispatch.evaluation_script())
    None => None
  }
}

///|
pub fn BundledBridgeHandoff::kind(self : BundledBridgeHandoff) -> String {
  match self.immediate_dispatch {
    Some(_) => "immediate"
    None => "deferred"
  }
}

///|
pub fn BundledBridgeHandoff::to_json(self : BundledBridgeHandoff) -> String {
  let immediate = match self.immediate_dispatch {
    Some(dispatch) => dispatch.to_json()
    None => "null"
  }
  [
    "{",
    "\"kind\":\{self.kind().json_string()},",
    "\"task\":\{self.task.to_json()},",
    "\"immediateDispatch\":\{immediate}",
    "}",
  ].join("")
}

///|
pub async fn BundledBridgeHandoff::complete_deferred(
  self : BundledBridgeHandoff,
  runtime : BundledRuntime,
) -> Result[BundledBridgeCompletion, String] {
  if self.requires_async_dispatch() {
    Ok(self.task.complete(runtime))
  } else {
    Err("bundled bridge handoff is immediate")
  }
}

///|
pub fn BundledBridgeCompletion::task(
  self : BundledBridgeCompletion,
) -> BundledBridgeDispatchTask {
  self.task
}

///|
pub fn BundledBridgeCompletion::dispatch(
  self : BundledBridgeCompletion,
) -> BundledBridgeDispatch {
  self.dispatch
}

///|
pub fn BundledBridgeCompletion::evaluation_script(
  self : BundledBridgeCompletion,
) -> String {
  self.dispatch.evaluation_script()
}

///|
pub fn BundledBridgeCompletion::operations(
  self : BundledBridgeCompletion,
) -> Array[@runtime.NativeExecutableOperation] {
  self.dispatch.operations()
}

///|
pub fn BundledBridgeCompletion::to_json(
  self : BundledBridgeCompletion,
) -> String {
  [
    "{",
    "\"task\":\{self.task.to_json()},",
    "\"dispatch\":\{self.dispatch.to_json()},",
    "\"evaluationScript\":\{self.evaluation_script().json_string()}",
    "}",
  ].join("")
}

///|
pub fn BundledBridgeDrainResult::new(
  pending_before~ : Int,
  pending_after~ : Int,
  completions~ : Array[BundledBridgeCompletion],
) -> BundledBridgeDrainResult {
  let evaluation_scripts : Array[String] = []
  let operations : Array[@runtime.NativeExecutableOperation] = []
  for completion in completions {
    evaluation_scripts.push(completion.evaluation_script())
    for operation in completion.operations() {
      operations.push(operation)
    }
  }
  {
    pending_before,
    pending_after,
    completions: completions.copy(),
    evaluation_scripts,
    operations,
  }
}

///|
pub fn BundledBridgeDrainResult::pending_before(
  self : BundledBridgeDrainResult,
) -> Int {
  self.pending_before
}

///|
pub fn BundledBridgeDrainResult::pending_after(
  self : BundledBridgeDrainResult,
) -> Int {
  self.pending_after
}

///|
pub fn BundledBridgeDrainResult::completed_count(
  self : BundledBridgeDrainResult,
) -> Int {
  self.completions.length()
}

///|
pub fn BundledBridgeDrainResult::completions(
  self : BundledBridgeDrainResult,
) -> Array[BundledBridgeCompletion] {
  self.completions.copy()
}

///|
pub fn BundledBridgeDrainResult::completed_routes(
  self : BundledBridgeDrainResult,
) -> Array[String] {
  self.completions.map(fn(completion) { completion.task().route() })
}

///|
pub fn BundledBridgeDrainResult::evaluation_scripts(
  self : BundledBridgeDrainResult,
) -> Array[String] {
  self.evaluation_scripts.copy()
}

///|
pub fn BundledBridgeDrainResult::operations(
  self : BundledBridgeDrainResult,
) -> Array[@runtime.NativeExecutableOperation] {
  self.operations.copy()
}

///|
pub fn BundledBridgeDrainResult::is_empty(
  self : BundledBridgeDrainResult,
) -> Bool {
  self.completed_count() == 0
}

///|
pub fn BundledBridgeDrainResult::to_json(
  self : BundledBridgeDrainResult,
) -> String {
  [
    "{",
    "\"pendingBefore\":\{self.pending_before},",
    "\"pendingAfter\":\{self.pending_after},",
    "\"completedCount\":\{self.completed_count()},",
    "\"completedRoutes\":[\{self.completed_routes().map(fn(route) { route.json_string() }).join(",")}],",
    "\"evaluationScripts\":[\{self.evaluation_scripts.map(fn(script) { script.json_string() }).join(",")}],",
    "\"operations\":[\{self.operations.map(fn(operation) { operation.to_json() }).join(",")}],",
    "\"completions\":[\{self.completions.map(fn(completion) { completion.to_json() }).join(",")}]",
    "}",
  ].join("")
}

///|
pub fn BundledBridgeWorkQueue::new() -> BundledBridgeWorkQueue {
  { tasks: [] }
}

///|
pub fn BundledBridgeWorkQueue::pending_count(
  self : BundledBridgeWorkQueue,
) -> Int {
  self.tasks.length()
}

///|
pub fn BundledBridgeWorkQueue::is_empty(self : BundledBridgeWorkQueue) -> Bool {
  self.tasks.is_empty()
}

///|
pub fn BundledBridgeWorkQueue::tasks(
  self : BundledBridgeWorkQueue,
) -> Array[BundledBridgeDispatchTask] {
  self.tasks.copy()
}

///|
pub fn BundledBridgeWorkQueue::enqueue_task(
  self : BundledBridgeWorkQueue,
  task : BundledBridgeDispatchTask,
) -> Result[Int, String] {
  if task.requires_async_dispatch() {
    self.tasks.push(task)
    Ok(self.pending_count())
  } else {
    Err("bundled bridge queue only accepts async dispatch tasks")
  }
}

///|
pub fn BundledBridgeWorkQueue::enqueue_handoff(
  self : BundledBridgeWorkQueue,
  handoff : BundledBridgeHandoff,
) -> Result[Int, String] {
  if handoff.requires_async_dispatch() {
    self.enqueue_task(handoff.task())
  } else {
    Err("bundled bridge queue only accepts deferred async handoffs")
  }
}

///|
pub fn BundledBridgeWorkQueue::handoff_script_bytes(
  self : BundledBridgeWorkQueue,
  runtime : BundledRuntime,
  message : Bytes,
) -> Bytes {
  let input = @utf8.decode(message) catch { _ => "" }
  match runtime.bridge_handoff(input) {
    Ok(handoff) =>
      match handoff.immediate_script() {
        Some(script) => @utf8.encode(script)
        None => {
          ignore(self.enqueue_handoff(handoff))
          @utf8.encode("")
        }
      }
    Err(_) => @utf8.encode("")
  }
}

///|
pub fn BundledBridgeWorkQueue::handoff_callback(
  self : BundledBridgeWorkQueue,
  runtime : BundledRuntime,
) -> (Bytes) -> Bytes {
  fn(message : Bytes) { self.handoff_script_bytes(runtime, message) }
}

///|
pub async fn BundledBridgeWorkQueue::drain(
  self : BundledBridgeWorkQueue,
  runtime : BundledRuntime,
) -> Array[BundledBridgeCompletion] {
  let tasks = self.tasks.copy()
  self.tasks.clear()
  let completions : Array[BundledBridgeCompletion] = []
  for task in tasks {
    completions.push(task.complete(runtime))
  }
  completions
}

///|
pub async fn BundledBridgeWorkQueue::drain_result(
  self : BundledBridgeWorkQueue,
  runtime : BundledRuntime,
) -> BundledBridgeDrainResult {
  let pending_before = self.pending_count()
  let completions = self.drain(runtime)
  BundledBridgeDrainResult::new(
    pending_before~,
    pending_after=self.pending_count(),
    completions~,
  )
}

///|
pub fn BundledBridgeWorkQueue::to_json(self : BundledBridgeWorkQueue) -> String {
  [
    "{",
    "\"pendingCount\":\{self.pending_count()},",
    "\"tasks\":[\{self.tasks.map(fn(task) { task.to_json() }).join(",")}]",
    "}",
  ].join("")
}

///|
pub fn BundledBridgeLoopAdapter::new(
  runtime : BundledRuntime,
) -> BundledBridgeLoopAdapter {
  { runtime, queue: BundledBridgeWorkQueue::new() }
}

///|
pub fn BundledRuntime::bridge_loop_adapter(
  self : BundledRuntime,
) -> BundledBridgeLoopAdapter {
  BundledBridgeLoopAdapter::new(self)
}

///|
pub fn BundledRuntimeManifest::bridge_loop_adapter(
  self : BundledRuntimeManifest,
) -> BundledBridgeLoopAdapter {
  BundledRuntime::new(self).bridge_loop_adapter()
}

///|
pub fn BundledBridgeLoopAdapter::runtime(
  self : BundledBridgeLoopAdapter,
) -> BundledRuntime {
  self.runtime
}

///|
pub fn BundledBridgeLoopAdapter::queue(
  self : BundledBridgeLoopAdapter,
) -> BundledBridgeWorkQueue {
  self.queue
}

///|
pub fn BundledBridgeLoopAdapter::pending_count(
  self : BundledBridgeLoopAdapter,
) -> Int {
  self.queue.pending_count()
}

///|
pub fn BundledBridgeLoopAdapter::is_empty(
  self : BundledBridgeLoopAdapter,
) -> Bool {
  self.queue.is_empty()
}

///|
pub fn BundledBridgeLoopAdapter::handoff_script_bytes(
  self : BundledBridgeLoopAdapter,
  message : Bytes,
) -> Bytes {
  self.queue.handoff_script_bytes(self.runtime, message)
}

///|
pub fn BundledBridgeLoopAdapter::handoff_callback(
  self : BundledBridgeLoopAdapter,
) -> (Bytes) -> Bytes {
  self.queue.handoff_callback(self.runtime)
}

///|
pub fn BundledBridgeLoopAdapter::handoff_packet_bytes(
  self : BundledBridgeLoopAdapter,
  message : Bytes,
) -> Bytes {
  let input = @utf8.decode(message) catch { _ => "" }
  match self.runtime.bridge_handoff(input) {
    Ok(handoff) =>
      match handoff.immediate_dispatch() {
        Some(dispatch) =>
          @utf8.encode(
            bundled_bridge_handoff_packet(
              "immediate",
              handoff.task().window_label(),
              dispatch.evaluation_script(),
              operations=dispatch.operations(),
            ),
          )
        None => {
          let count = self.queue
            .enqueue_handoff(handoff)
            .unwrap_or(self.queue.pending_count())
          @utf8.encode(
            bundled_bridge_handoff_packet(
              "deferred",
              handoff.task().window_label(),
              "\{count}",
              operations=[],
            ),
          )
        }
      }
    Err(problems) =>
      @utf8.encode(
        bundled_bridge_handoff_packet("error", "", problems.join("; "), operations=[]),
      )
  }
}

///|
pub fn BundledBridgeLoopAdapter::handoff_packet_callback(
  self : BundledBridgeLoopAdapter,
) -> (Bytes) -> Bytes {
  fn(message : Bytes) { self.handoff_packet_bytes(message) }
}

///|
pub fn BundledBridgeLoopAdapter::callbacks(
  self : BundledBridgeLoopAdapter,
  window_label~ : String,
) -> BundledBridgeLoopCallbacks {
  {
    window_label,
    handoff_callback: self.handoff_callback(),
    handoff_packet_callback: self.handoff_packet_callback(),
    drain_window_callback: () => self.drain_window(window_label~),
  }
}

///|
pub async fn BundledBridgeLoopAdapter::drain(
  self : BundledBridgeLoopAdapter,
) -> Array[BundledBridgeCompletion] {
  self.queue.drain(self.runtime)
}

///|
pub async fn BundledBridgeLoopAdapter::drain_result(
  self : BundledBridgeLoopAdapter,
) -> BundledBridgeDrainResult {
  self.queue.drain_result(self.runtime)
}

///|
pub async fn BundledBridgeLoopAdapter::receive_message(
  self : BundledBridgeLoopAdapter,
  message : Bytes,
) -> BundledBridgeLoopResult {
  let immediate_script = @utf8.decode(self.handoff_script_bytes(message)) catch {
    _ => ""
  }
  { immediate_script, completions: self.drain() }
}

///|
pub async fn BundledBridgeLoopAdapter::receive_window_message(
  self : BundledBridgeLoopAdapter,
  window_label~ : String,
  message : Bytes,
) -> BundledBridgeLoopDelivery {
  BundledBridgeLoopDelivery::from_result(
    window_label~,
    result=self.receive_message(message),
  )
}

///|
pub async fn BundledBridgeLoopAdapter::drain_window(
  self : BundledBridgeLoopAdapter,
  window_label~ : String,
) -> BundledBridgeLoopDelivery {
  BundledBridgeLoopDelivery::from_result(window_label~, result={
    immediate_script: "",
    completions: self.drain(),
  })
}

///|
pub fn BundledBridgeLoopAdapter::to_json(
  self : BundledBridgeLoopAdapter,
) -> String {
  self.queue.to_json()
}

///|
pub fn BundledBridgeLoopCallbacks::window_label(
  self : BundledBridgeLoopCallbacks,
) -> String {
  self.window_label
}

///|
pub fn BundledBridgeLoopCallbacks::handoff_callback(
  self : BundledBridgeLoopCallbacks,
) -> (Bytes) -> Bytes {
  self.handoff_callback
}

///|
pub fn BundledBridgeLoopCallbacks::handoff_packet_callback(
  self : BundledBridgeLoopCallbacks,
) -> (Bytes) -> Bytes {
  self.handoff_packet_callback
}

///|
pub async fn BundledBridgeLoopCallbacks::drain_window(
  self : BundledBridgeLoopCallbacks,
) -> BundledBridgeLoopDelivery {
  (self.drain_window_callback)()
}

///|
pub async fn BundledBridgeLoopCallbacks::drain_window_json(
  self : BundledBridgeLoopCallbacks,
) -> Bytes {
  @utf8.encode(self.drain_window().to_json())
}

///|
pub async fn BundledBridgeLoopCallbacks::drain_window_scripts(
  self : BundledBridgeLoopCallbacks,
) -> Bytes {
  @utf8.encode(self.drain_window().result().evaluation_scripts().join("\n"))
}

///|
pub fn BundledBridgeLoopCallbacks::drain_window_operation(
  self : BundledBridgeLoopCallbacks,
) -> @runtime.NativeExecutableOperation {
  @runtime.NativeExecutableOperation::drain_bridge(
    @runtime.NativeBridgeDrain::new(
      window_label=self.window_label,
      callback="bridge_loop_adapter().callbacks(\{self.window_label}).drain_window_scripts",
    ),
  )
}

///|
pub fn BundledBridgeLoopCallbacks::to_json(
  self : BundledBridgeLoopCallbacks,
) -> String {
  [
    "{",
    "\"windowLabel\":\{self.window_label.json_string()},",
    "\"handoffCallback\":\"(Bytes)->Bytes\",",
    "\"handoffPacketCallback\":\"(Bytes)->utf8-handoff-packet\",",
    "\"drainWindow\":\"async()->BundledBridgeLoopDelivery\",",
    "\"drainWindowScripts\":\"async()->utf8-javascript-callback-script\",",
    "\"drainWindowOperation\":\"NativeExecutableOperation::drain_bridge\",",
    "\"drainWindowJson\":\"async()->utf8-json-bridge-loop-delivery\"",
    "}",
  ].join("")
}

///|
fn bundled_bridge_handoff_packet(
  status : String,
  window_label : String,
  body : String,
  operations~ : Array[@runtime.NativeExecutableOperation],
) -> String {
  "\{status}\n\{window_label}\n\{@utf8.encode(body).length()}\n\{body}\n\{@runtime.native_executable_operations_packet(operations)}"
}

///|
pub fn BundledBridgeLoopResult::immediate_script(
  self : BundledBridgeLoopResult,
) -> String {
  self.immediate_script
}

///|
pub fn BundledBridgeLoopResult::has_immediate_script(
  self : BundledBridgeLoopResult,
) -> Bool {
  self.immediate_script != ""
}

///|
pub fn BundledBridgeLoopResult::completions(
  self : BundledBridgeLoopResult,
) -> Array[BundledBridgeCompletion] {
  self.completions.copy()
}

///|
pub fn BundledBridgeLoopResult::evaluation_scripts(
  self : BundledBridgeLoopResult,
) -> Array[String] {
  let scripts : Array[String] = []
  if self.has_immediate_script() {
    scripts.push(self.immediate_script)
  }
  for completion in self.completions {
    scripts.push(completion.evaluation_script())
  }
  scripts
}

///|
pub fn BundledBridgeLoopResult::operations(
  self : BundledBridgeLoopResult,
  window_label~ : String,
) -> Array[@runtime.NativeExecutableOperation] {
  let operations : Array[@runtime.NativeExecutableOperation] = []
  if self.has_immediate_script() {
    operations.push(
      @runtime.NativeExecutableOperation::evaluate_script(
        @runtime.NativeEvaluationScript::new(
          window_label~,
          script=self.immediate_script,
        ),
      ),
    )
  }
  for completion in self.completions {
    for operation in completion.operations() {
      operations.push(operation)
    }
  }
  operations
}

///|
pub fn BundledBridgeLoopResult::evaluation_plan(
  self : BundledBridgeLoopResult,
  window_label~ : String,
) -> @runtime.NativeBridgeLoopEvaluationPlan {
  @runtime.NativeBridgeLoopEvaluationPlan::new(
    window_label~,
    operations=self.operations(window_label~),
  )
}

///|
pub fn BundledBridgeLoopDelivery::from_result(
  window_label~ : String,
  result~ : BundledBridgeLoopResult,
) -> BundledBridgeLoopDelivery {
  {
    window_label,
    result,
    evaluation_plan: result.evaluation_plan(window_label~),
  }
}

///|
pub fn BundledBridgeLoopDelivery::window_label(
  self : BundledBridgeLoopDelivery,
) -> String {
  self.window_label
}

///|
pub fn BundledBridgeLoopDelivery::result(
  self : BundledBridgeLoopDelivery,
) -> BundledBridgeLoopResult {
  self.result
}

///|
pub fn BundledBridgeLoopDelivery::evaluation_plan(
  self : BundledBridgeLoopDelivery,
) -> @runtime.NativeBridgeLoopEvaluationPlan {
  self.evaluation_plan
}

///|
pub fn BundledBridgeLoopDelivery::operations(
  self : BundledBridgeLoopDelivery,
) -> Array[@runtime.NativeExecutableOperation] {
  self.evaluation_plan.operations()
}

///|
pub fn BundledBridgeLoopDelivery::is_empty(
  self : BundledBridgeLoopDelivery,
) -> Bool {
  self.evaluation_plan.is_empty()
}

///|
pub fn BundledBridgeLoopDelivery::to_json(
  self : BundledBridgeLoopDelivery,
) -> String {
  [
    "{",
    "\"windowLabel\":\{self.window_label.json_string()},",
    "\"result\":\{self.result.to_json()},",
    "\"evaluationPlan\":\{self.evaluation_plan.to_json()}",
    "}",
  ].join("")
}

///|
pub fn BundledBridgeLoopResult::to_json(
  self : BundledBridgeLoopResult,
) -> String {
  [
    "{",
    "\"immediateScript\":\{self.immediate_script.json_string()},",
    "\"completions\":[\{self.completions.map(fn(completion) { completion.to_json() }).join(",")}],",
    "\"evaluationScripts\":[\{self.evaluation_scripts().map(fn(script) { script.json_string() }).join(",")}]",
    "}",
  ].join("")
}

///|
pub fn BundledBridgeDispatch::window_label(
  self : BundledBridgeDispatch,
) -> String {
  self.window_label
}

///|
pub fn BundledBridgeDispatch::response_hook(
  self : BundledBridgeDispatch,
) -> String {
  self.response_hook
}

///|
pub fn BundledBridgeDispatch::message(self : BundledBridgeDispatch) -> String {
  self.message
}

///|
pub fn BundledBridgeDispatch::response_json(
  self : BundledBridgeDispatch,
) -> String {
  self.response_json
}

///|
pub fn BundledBridgeDispatch::evaluation_script(
  self : BundledBridgeDispatch,
) -> String {
  self.evaluation_script
}

///|
pub fn BundledBridgeDispatch::native_window_control(
  self : BundledBridgeDispatch,
) -> @runtime.NativeWindowControl? {
  @runtime.native_window_control_from_bridge_response(
    self.message,
    self.response_json,
  )
}

///|
pub fn BundledBridgeDispatch::operations(
  self : BundledBridgeDispatch,
) -> Array[@runtime.NativeExecutableOperation] {
  let operations : Array[@runtime.NativeExecutableOperation] = [
    @runtime.NativeExecutableOperation::evaluate_script(
      @runtime.NativeEvaluationScript::new(
        window_label=self.window_label,
        script=self.evaluation_script,
      ),
    ),
  ]
  for operation in self.extra_operations {
    operations.push(operation)
  }
  match self.native_window_control() {
    Some(control) =>
      operations.push(
        @runtime.NativeExecutableOperation::window_control(control),
      )
    None => ()
  }
  operations
}

///|
pub fn BundledBridgeDispatch::to_json(self : BundledBridgeDispatch) -> String {
  let control_json = match self.native_window_control() {
    Some(control) => control.to_json()
    None => "null"
  }
  [
    "{",
    "\"windowLabel\":\{self.window_label.json_string()},",
    "\"responseHook\":\{self.response_hook.json_string()},",
    "\"message\":\{self.message.json_string()},",
    "\"responseJson\":\{self.response_json.json_string()},",
    "\"evaluationScript\":\{self.evaluation_script.json_string()},",
    "\"extraOperations\":[\{self.extra_operations.map(fn(operation) { operation.to_json() }).join(",")}],",
    "\"nativeWindowControl\":\{control_json},",
    "\"operations\":[\{self.operations().map(fn(operation) { operation.to_json() }).join(",")}]",
    "}",
  ].join("")
}

///|
fn bundled_bridge_window_label_from_message(
  message : String,
  window_label~ : String,
) -> String {
  if window_label != "" {
    window_label
  } else {
    match @runtime.decode_invoke_request_json(message) {
      Ok(request) => request.window_label()
      Err(_) => ""
    }
  }
}
