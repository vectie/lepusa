///|
pub struct NativeBridgeMessage {
  window_label : String
  response_hook : String
  message : String
} derive(Debug, Eq)

///|
pub struct NativeBridgeDispatch {
  window_label : String
  response_hook : String
  message : String
  response_json : String
  evaluation_script : String
} derive(Debug, Eq)

///|
pub(all) enum NativeBridgeDispatchMode {
  NativeBridgeDispatchSync
  NativeBridgeDispatchAsync
} derive(Debug, Eq)

///|
pub struct NativeBridgeDispatchTask {
  message : NativeBridgeMessage
  route : String
  mode : NativeBridgeDispatchMode
} derive(Debug, Eq)

///|
pub struct NativeBridgeHandoff {
  task : NativeBridgeDispatchTask
  immediate_dispatch : NativeBridgeDispatch?
} derive(Debug, Eq)

///|
pub struct NativeBridgeCompletion {
  task : NativeBridgeDispatchTask
  dispatch : NativeBridgeDispatch
} derive(Debug, Eq)

///|
pub struct NativeBridgeWorkQueue {
  tasks : Array[NativeBridgeDispatchTask]
} derive(Debug, Eq)

///|
pub struct NativeBridgeLoopAdapter {
  runtime : NativeRuntime
  queue : NativeBridgeWorkQueue
}

///|
pub struct NativeBridgeLoopCallbacks {
  window_label : String
  handoff_callback : (Bytes) -> Bytes
  handoff_packet_callback : (Bytes) -> Bytes
  drain_window_callback : async () -> NativeBridgeLoopDelivery
}

///|
pub struct NativeBridgeLoopResult {
  immediate_script : String
  completions : Array[NativeBridgeCompletion]
} derive(Debug, Eq)

///|
pub struct NativeBridgeLoopDelivery {
  window_label : String
  result : NativeBridgeLoopResult
  evaluation_plan : NativeBridgeLoopEvaluationPlan
} derive(Debug, Eq)

///|
pub fn RuntimeHost::prepare_bridge_message(
  self : RuntimeHost,
  message : String,
  window_label? : String = "",
) -> Result[NativeBridgeMessage, Array[String]] {
  let resolved_window_label = bridge_window_label_from_message(
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
pub fn RuntimeHost::bridge_dispatch_task(
  self : RuntimeHost,
  message : String,
  window_label? : String = "",
) -> Result[NativeBridgeDispatchTask, Array[String]] {
  match self.prepare_bridge_message(message, window_label~) {
    Err(problems) => Err(problems)
    Ok(prepared) =>
      match decode_invoke_request_json(message) {
        Err(problem) => Err([problem])
        Ok(request) => {
          let route = request.route()
          let mode = if self.async_command_routes().contains(route) {
            NativeBridgeDispatchAsync
          } else {
            NativeBridgeDispatchSync
          }
          Ok({ message: prepared, route, mode })
        }
      }
  }
}

///|
pub fn RuntimeHost::bridge_handoff(
  self : RuntimeHost,
  message : String,
  window_label? : String = "",
) -> Result[NativeBridgeHandoff, Array[String]] {
  match self.bridge_dispatch_task(message, window_label~) {
    Err(problems) => Err(problems)
    Ok(task) => {
      let immediate_dispatch = if task.requires_async_dispatch() {
        None
      } else {
        Some(task.dispatch_host_sync(self))
      }
      Ok({ task, immediate_dispatch })
    }
  }
}

///|
pub async fn RuntimeHost::dispatch_bridge_message(
  self : RuntimeHost,
  message : String,
  window_label? : String = "",
) -> Result[NativeBridgeDispatch, Array[String]] {
  match self.prepare_bridge_message(message, window_label~) {
    Err(problems) => Err(problems)
    Ok(prepared) => Ok(prepared.dispatch_host(self))
  }
}

///|
pub fn RuntimeHost::dispatch_bridge_message_sync(
  self : RuntimeHost,
  message : String,
  window_label? : String = "",
) -> Result[NativeBridgeDispatch, Array[String]] {
  match self.prepare_bridge_message(message, window_label~) {
    Err(problems) => Err(problems)
    Ok(prepared) => Ok(prepared.dispatch_host_sync(self))
  }
}

///|
pub fn NativeRuntime::prepare_bridge_message(
  self : NativeRuntime,
  message : String,
  window_label? : String = "",
) -> Result[NativeBridgeMessage, Array[String]] {
  let resolved_window_label = bridge_window_label_from_message(
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
pub fn NativeRuntime::bridge_dispatch_task(
  self : NativeRuntime,
  message : String,
  window_label? : String = "",
) -> Result[NativeBridgeDispatchTask, Array[String]] {
  match self.prepare_bridge_message(message, window_label~) {
    Err(problems) => Err(problems)
    Ok(prepared) =>
      match decode_invoke_request_json(message) {
        Err(problem) => Err([problem])
        Ok(request) => {
          let route = request.route()
          let mode = if self.host.async_command_routes().contains(route) {
            NativeBridgeDispatchAsync
          } else {
            NativeBridgeDispatchSync
          }
          Ok({ message: prepared, route, mode })
        }
      }
  }
}

///|
pub fn NativeRuntime::bridge_handoff(
  self : NativeRuntime,
  message : String,
  window_label? : String = "",
) -> Result[NativeBridgeHandoff, Array[String]] {
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
pub async fn NativeRuntime::dispatch_bridge_message(
  self : NativeRuntime,
  message : String,
  window_label? : String = "",
) -> Result[NativeBridgeDispatch, Array[String]] {
  match self.prepare_bridge_message(message, window_label~) {
    Err(problems) => Err(problems)
    Ok(prepared) => Ok(prepared.dispatch(self))
  }
}

///|
pub fn NativeRuntime::dispatch_bridge_message_sync(
  self : NativeRuntime,
  message : String,
  window_label? : String = "",
) -> Result[NativeBridgeDispatch, Array[String]] {
  match self.prepare_bridge_message(message, window_label~) {
    Err(problems) => Err(problems)
    Ok(prepared) => Ok(prepared.dispatch_sync(self))
  }
}

///|
pub fn NativeRuntime::dispatch_bridge_script_bytes(
  self : NativeRuntime,
  message : Bytes,
) -> Bytes {
  let input = @utf8.decode(message) catch { _ => "" }
  match self.dispatch_bridge_message_sync(input) {
    Ok(dispatch) => @utf8.encode(dispatch.evaluation_script())
    Err(_) => @utf8.encode("")
  }
}

///|
pub fn NativeRuntime::bridge_handoff_script_bytes(
  self : NativeRuntime,
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
pub fn NativeRuntime::bridge_response_hook(
  self : NativeRuntime,
  window_label? : String = "",
) -> Result[(String, String), String] {
  let specs = self.runner.webview_specs()
  if specs.is_empty() {
    return Err("native bridge dispatch requires at least one webview")
  }
  if window_label != "" {
    for spec in specs {
      if spec.label() == window_label {
        return Ok((spec.label(), "\{spec.native_hook()}Response"))
      }
    }
    return Err("native bridge window not found: \{window_label}")
  }
  let spec = specs[0]
  Ok((spec.label(), "\{spec.native_hook()}Response"))
}

///|
pub fn RuntimeHost::bridge_response_hook(
  self : RuntimeHost,
  window_label? : String = "",
) -> Result[(String, String), String] {
  match self.webviews() {
    Err(problems) => Err(problems.join("; "))
    Ok(specs) => {
      if specs.is_empty() {
        return Err("runtime bridge dispatch requires at least one webview")
      }
      if window_label != "" {
        for spec in specs {
          if spec.label() == window_label {
            return Ok((spec.label(), "\{spec.native_hook()}Response"))
          }
        }
        return Err("runtime bridge window not found: \{window_label}")
      }
      let spec = specs[0]
      Ok((spec.label(), "\{spec.native_hook()}Response"))
    }
  }
}

///|
pub async fn NativeBridgeMessage::dispatch(
  self : NativeBridgeMessage,
  runtime : NativeRuntime,
) -> NativeBridgeDispatch {
  let response_json = runtime.dispatch_json_async(self.message)
  self.to_dispatch(response_json)
}

///|
async fn NativeBridgeMessage::dispatch_host(
  self : NativeBridgeMessage,
  host : RuntimeHost,
) -> NativeBridgeDispatch {
  let response_json = host.dispatch_json_async(self.message)
  self.to_dispatch(response_json)
}

///|
pub fn NativeBridgeMessage::dispatch_sync(
  self : NativeBridgeMessage,
  runtime : NativeRuntime,
) -> NativeBridgeDispatch {
  let response_json = runtime.dispatch_json(self.message)
  self.to_dispatch(response_json)
}

///|
fn NativeBridgeMessage::dispatch_host_sync(
  self : NativeBridgeMessage,
  host : RuntimeHost,
) -> NativeBridgeDispatch {
  let response_json = host.dispatch_json(self.message)
  self.to_dispatch(response_json)
}

///|
fn NativeBridgeMessage::to_dispatch(
  self : NativeBridgeMessage,
  response_json : String,
) -> NativeBridgeDispatch {
  {
    window_label: self.window_label,
    response_hook: self.response_hook,
    message: self.message,
    response_json,
    evaluation_script: native_bridge_response_script(
      self.response_hook,
      response_json,
    ),
  }
}

///|
pub fn NativeBridgeMessage::window_label(self : NativeBridgeMessage) -> String {
  self.window_label
}

///|
pub fn NativeBridgeMessage::response_hook(self : NativeBridgeMessage) -> String {
  self.response_hook
}

///|
pub fn NativeBridgeMessage::message(self : NativeBridgeMessage) -> String {
  self.message
}

///|
pub fn NativeBridgeDispatchMode::name(
  self : NativeBridgeDispatchMode,
) -> String {
  match self {
    NativeBridgeDispatchSync => "sync"
    NativeBridgeDispatchAsync => "async"
  }
}

///|
pub fn NativeBridgeDispatchTask::message(
  self : NativeBridgeDispatchTask,
) -> NativeBridgeMessage {
  self.message
}

///|
pub fn NativeBridgeDispatchTask::window_label(
  self : NativeBridgeDispatchTask,
) -> String {
  self.message.window_label()
}

///|
pub fn NativeBridgeDispatchTask::response_hook(
  self : NativeBridgeDispatchTask,
) -> String {
  self.message.response_hook()
}

///|
pub fn NativeBridgeDispatchTask::route(
  self : NativeBridgeDispatchTask,
) -> String {
  self.route
}

///|
pub fn NativeBridgeDispatchTask::mode(
  self : NativeBridgeDispatchTask,
) -> NativeBridgeDispatchMode {
  self.mode
}

///|
pub fn NativeBridgeDispatchTask::requires_async_dispatch(
  self : NativeBridgeDispatchTask,
) -> Bool {
  self.mode == NativeBridgeDispatchAsync
}

///|
pub async fn NativeBridgeDispatchTask::dispatch(
  self : NativeBridgeDispatchTask,
  runtime : NativeRuntime,
) -> NativeBridgeDispatch {
  match self.mode {
    NativeBridgeDispatchSync => self.message.dispatch_sync(runtime)
    NativeBridgeDispatchAsync => self.message.dispatch(runtime)
  }
}

///|
pub async fn NativeBridgeDispatchTask::complete(
  self : NativeBridgeDispatchTask,
  runtime : NativeRuntime,
) -> NativeBridgeCompletion {
  { task: self, dispatch: self.dispatch(runtime) }
}

///|
fn NativeBridgeDispatchTask::dispatch_sync(
  self : NativeBridgeDispatchTask,
  runtime : NativeRuntime,
) -> NativeBridgeDispatch {
  self.message.dispatch_sync(runtime)
}

///|
fn NativeBridgeDispatchTask::dispatch_host_sync(
  self : NativeBridgeDispatchTask,
  host : RuntimeHost,
) -> NativeBridgeDispatch {
  self.message.dispatch_host_sync(host)
}

///|
pub fn NativeBridgeDispatchTask::to_json(
  self : NativeBridgeDispatchTask,
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
pub fn NativeBridgeHandoff::task(
  self : NativeBridgeHandoff,
) -> NativeBridgeDispatchTask {
  self.task
}

///|
pub fn NativeBridgeHandoff::mode(
  self : NativeBridgeHandoff,
) -> NativeBridgeDispatchMode {
  self.task.mode()
}

///|
pub fn NativeBridgeHandoff::requires_async_dispatch(
  self : NativeBridgeHandoff,
) -> Bool {
  self.task.requires_async_dispatch()
}

///|
pub fn NativeBridgeHandoff::immediate_dispatch(
  self : NativeBridgeHandoff,
) -> NativeBridgeDispatch? {
  self.immediate_dispatch
}

///|
pub fn NativeBridgeHandoff::immediate_script(
  self : NativeBridgeHandoff,
) -> String? {
  match self.immediate_dispatch {
    Some(dispatch) => Some(dispatch.evaluation_script())
    None => None
  }
}

///|
pub fn NativeBridgeHandoff::kind(self : NativeBridgeHandoff) -> String {
  match self.immediate_dispatch {
    Some(_) => "immediate"
    None => "deferred"
  }
}

///|
pub fn NativeBridgeHandoff::to_json(self : NativeBridgeHandoff) -> String {
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
pub async fn NativeBridgeHandoff::complete_deferred(
  self : NativeBridgeHandoff,
  runtime : NativeRuntime,
) -> Result[NativeBridgeCompletion, String] {
  if self.requires_async_dispatch() {
    Ok(self.task.complete(runtime))
  } else {
    Err("native bridge handoff is immediate")
  }
}

///|
pub fn NativeBridgeCompletion::task(
  self : NativeBridgeCompletion,
) -> NativeBridgeDispatchTask {
  self.task
}

///|
pub fn NativeBridgeCompletion::dispatch(
  self : NativeBridgeCompletion,
) -> NativeBridgeDispatch {
  self.dispatch
}

///|
pub fn NativeBridgeCompletion::evaluation_script(
  self : NativeBridgeCompletion,
) -> String {
  self.dispatch.evaluation_script()
}

///|
pub fn NativeBridgeCompletion::to_json(self : NativeBridgeCompletion) -> String {
  [
    "{",
    "\"task\":\{self.task.to_json()},",
    "\"dispatch\":\{self.dispatch.to_json()},",
    "\"evaluationScript\":\{self.evaluation_script().json_string()}",
    "}",
  ].join("")
}

///|
pub fn NativeBridgeWorkQueue::new() -> NativeBridgeWorkQueue {
  { tasks: [] }
}

///|
pub fn NativeBridgeWorkQueue::pending_count(
  self : NativeBridgeWorkQueue,
) -> Int {
  self.tasks.length()
}

///|
pub fn NativeBridgeWorkQueue::is_empty(self : NativeBridgeWorkQueue) -> Bool {
  self.tasks.is_empty()
}

///|
pub fn NativeBridgeWorkQueue::tasks(
  self : NativeBridgeWorkQueue,
) -> Array[NativeBridgeDispatchTask] {
  self.tasks.copy()
}

///|
pub fn NativeBridgeWorkQueue::enqueue_task(
  self : NativeBridgeWorkQueue,
  task : NativeBridgeDispatchTask,
) -> Result[Int, String] {
  if task.requires_async_dispatch() {
    self.tasks.push(task)
    Ok(self.pending_count())
  } else {
    Err("native bridge queue only accepts async dispatch tasks")
  }
}

///|
pub fn NativeBridgeWorkQueue::enqueue_handoff(
  self : NativeBridgeWorkQueue,
  handoff : NativeBridgeHandoff,
) -> Result[Int, String] {
  if handoff.requires_async_dispatch() {
    self.enqueue_task(handoff.task())
  } else {
    Err("native bridge queue only accepts deferred async handoffs")
  }
}

///|
pub fn NativeBridgeWorkQueue::handoff_script_bytes(
  self : NativeBridgeWorkQueue,
  runtime : NativeRuntime,
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
pub fn NativeBridgeWorkQueue::handoff_callback(
  self : NativeBridgeWorkQueue,
  runtime : NativeRuntime,
) -> (Bytes) -> Bytes {
  fn(message : Bytes) { self.handoff_script_bytes(runtime, message) }
}

///|
pub async fn NativeBridgeWorkQueue::drain(
  self : NativeBridgeWorkQueue,
  runtime : NativeRuntime,
) -> Array[NativeBridgeCompletion] {
  let tasks = self.tasks.copy()
  self.tasks.clear()
  let completions : Array[NativeBridgeCompletion] = []
  for task in tasks {
    completions.push(task.complete(runtime))
  }
  completions
}

///|
pub fn NativeBridgeWorkQueue::to_json(self : NativeBridgeWorkQueue) -> String {
  [
    "{",
    "\"pendingCount\":\{self.pending_count()},",
    "\"tasks\":[\{self.tasks.map(fn(task) { task.to_json() }).join(",")}]",
    "}",
  ].join("")
}

///|
pub fn NativeBridgeLoopAdapter::new(
  runtime : NativeRuntime,
) -> NativeBridgeLoopAdapter {
  { runtime, queue: NativeBridgeWorkQueue::new() }
}

///|
pub fn NativeRuntime::bridge_loop_adapter(
  self : NativeRuntime,
) -> NativeBridgeLoopAdapter {
  NativeBridgeLoopAdapter::new(self)
}

///|
pub fn NativeBridgeLoopAdapter::runtime(
  self : NativeBridgeLoopAdapter,
) -> NativeRuntime {
  self.runtime
}

///|
pub fn NativeBridgeLoopAdapter::queue(
  self : NativeBridgeLoopAdapter,
) -> NativeBridgeWorkQueue {
  self.queue
}

///|
pub fn NativeBridgeLoopAdapter::pending_count(
  self : NativeBridgeLoopAdapter,
) -> Int {
  self.queue.pending_count()
}

///|
pub fn NativeBridgeLoopAdapter::is_empty(
  self : NativeBridgeLoopAdapter,
) -> Bool {
  self.queue.is_empty()
}

///|
pub fn NativeBridgeLoopAdapter::handoff_script_bytes(
  self : NativeBridgeLoopAdapter,
  message : Bytes,
) -> Bytes {
  self.queue.handoff_script_bytes(self.runtime, message)
}

///|
pub fn NativeBridgeLoopAdapter::handoff_callback(
  self : NativeBridgeLoopAdapter,
) -> (Bytes) -> Bytes {
  self.queue.handoff_callback(self.runtime)
}

///|
pub fn NativeBridgeLoopAdapter::handoff_packet_bytes(
  self : NativeBridgeLoopAdapter,
  message : Bytes,
) -> Bytes {
  let input = @utf8.decode(message) catch { _ => "" }
  match self.runtime.bridge_handoff(input) {
    Ok(handoff) =>
      match handoff.immediate_script() {
        Some(script) =>
          @utf8.encode(
            native_bridge_handoff_packet(
              "immediate",
              handoff.task().window_label(),
              script,
            ),
          )
        None => {
          let count = self.queue
            .enqueue_handoff(handoff)
            .unwrap_or(self.queue.pending_count())
          @utf8.encode(
            native_bridge_handoff_packet(
              "deferred",
              handoff.task().window_label(),
              "\{count}",
            ),
          )
        }
      }
    Err(problems) =>
      @utf8.encode(
        native_bridge_handoff_packet("error", "", problems.join("; ")),
      )
  }
}

///|
pub fn NativeBridgeLoopAdapter::handoff_packet_callback(
  self : NativeBridgeLoopAdapter,
) -> (Bytes) -> Bytes {
  fn(message : Bytes) { self.handoff_packet_bytes(message) }
}

///|
pub fn NativeBridgeLoopAdapter::callbacks(
  self : NativeBridgeLoopAdapter,
  window_label~ : String,
) -> NativeBridgeLoopCallbacks {
  {
    window_label,
    handoff_callback: self.handoff_callback(),
    handoff_packet_callback: self.handoff_packet_callback(),
    drain_window_callback: () => self.drain_window(window_label~),
  }
}

///|
pub async fn NativeBridgeLoopAdapter::drain(
  self : NativeBridgeLoopAdapter,
) -> Array[NativeBridgeCompletion] {
  self.queue.drain(self.runtime)
}

///|
pub async fn NativeBridgeLoopAdapter::receive_message(
  self : NativeBridgeLoopAdapter,
  message : Bytes,
) -> NativeBridgeLoopResult {
  let immediate_script = @utf8.decode(self.handoff_script_bytes(message)) catch {
    _ => ""
  }
  { immediate_script, completions: self.drain() }
}

///|
pub async fn NativeBridgeLoopAdapter::receive_window_message(
  self : NativeBridgeLoopAdapter,
  window_label~ : String,
  message : Bytes,
) -> NativeBridgeLoopDelivery {
  NativeBridgeLoopDelivery::from_result(
    window_label~,
    result=self.receive_message(message),
  )
}

///|
pub async fn NativeBridgeLoopAdapter::drain_window(
  self : NativeBridgeLoopAdapter,
  window_label~ : String,
) -> NativeBridgeLoopDelivery {
  NativeBridgeLoopDelivery::from_result(window_label~, result={
    immediate_script: "",
    completions: self.drain(),
  })
}

///|
pub fn NativeBridgeLoopAdapter::to_json(
  self : NativeBridgeLoopAdapter,
) -> String {
  self.queue.to_json()
}

///|
pub fn NativeBridgeLoopCallbacks::window_label(
  self : NativeBridgeLoopCallbacks,
) -> String {
  self.window_label
}

///|
pub fn NativeBridgeLoopCallbacks::handoff_callback(
  self : NativeBridgeLoopCallbacks,
) -> (Bytes) -> Bytes {
  self.handoff_callback
}

///|
pub fn NativeBridgeLoopCallbacks::handoff_packet_callback(
  self : NativeBridgeLoopCallbacks,
) -> (Bytes) -> Bytes {
  self.handoff_packet_callback
}

///|
pub async fn NativeBridgeLoopCallbacks::drain_window(
  self : NativeBridgeLoopCallbacks,
) -> NativeBridgeLoopDelivery {
  (self.drain_window_callback)()
}

///|
pub async fn NativeBridgeLoopCallbacks::drain_window_json(
  self : NativeBridgeLoopCallbacks,
) -> Bytes {
  @utf8.encode(self.drain_window().to_json())
}

///|
pub async fn NativeBridgeLoopCallbacks::drain_window_scripts(
  self : NativeBridgeLoopCallbacks,
) -> Bytes {
  @utf8.encode(self.drain_window().result().evaluation_scripts().join("\n"))
}

///|
pub fn NativeBridgeLoopCallbacks::drain_window_operation(
  self : NativeBridgeLoopCallbacks,
) -> NativeExecutableOperation {
  NativeExecutableOperation::drain_bridge(
    NativeBridgeDrain::new(
      window_label=self.window_label,
      callback="bridge_loop_adapter().callbacks(\{self.window_label}).drain_window_scripts",
    ),
  )
}

///|
pub fn NativeBridgeLoopCallbacks::to_json(
  self : NativeBridgeLoopCallbacks,
) -> String {
  [
    "{",
    "\"windowLabel\":\{self.window_label.json_string()},",
    "\"handoffCallback\":\"(Bytes)->Bytes\",",
    "\"handoffPacketCallback\":\"(Bytes)->utf8-handoff-packet\",",
    "\"drainWindow\":\"async()->NativeBridgeLoopDelivery\",",
    "\"drainWindowScripts\":\"async()->utf8-javascript-callback-script\",",
    "\"drainWindowOperation\":\"NativeExecutableOperation::drain_bridge\",",
    "\"drainWindowJson\":\"async()->utf8-json-bridge-loop-delivery\"",
    "}",
  ].join("")
}

///|
fn native_bridge_handoff_packet(
  status : String,
  window_label : String,
  body : String,
) -> String {
  "\{status}\n\{window_label}\n\{body}"
}

///|
pub fn NativeBridgeLoopResult::immediate_script(
  self : NativeBridgeLoopResult,
) -> String {
  self.immediate_script
}

///|
pub fn NativeBridgeLoopResult::new(
  immediate_script? : String = "",
  completions? : Array[NativeBridgeCompletion] = [],
) -> NativeBridgeLoopResult {
  { immediate_script, completions: completions.copy() }
}

///|
pub fn NativeBridgeLoopResult::has_immediate_script(
  self : NativeBridgeLoopResult,
) -> Bool {
  self.immediate_script != ""
}

///|
pub fn NativeBridgeLoopResult::completions(
  self : NativeBridgeLoopResult,
) -> Array[NativeBridgeCompletion] {
  self.completions.copy()
}

///|
pub fn NativeBridgeLoopResult::evaluation_scripts(
  self : NativeBridgeLoopResult,
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
pub fn NativeBridgeLoopResult::evaluation_plan(
  self : NativeBridgeLoopResult,
  window_label~ : String,
) -> NativeBridgeLoopEvaluationPlan {
  NativeBridgeLoopEvaluationPlan::from_scripts(
    window_label~,
    scripts=self.evaluation_scripts(),
  )
}

///|
pub fn NativeBridgeLoopDelivery::from_result(
  window_label~ : String,
  result~ : NativeBridgeLoopResult,
) -> NativeBridgeLoopDelivery {
  {
    window_label,
    result,
    evaluation_plan: result.evaluation_plan(window_label~),
  }
}

///|
pub fn NativeBridgeLoopDelivery::window_label(
  self : NativeBridgeLoopDelivery,
) -> String {
  self.window_label
}

///|
pub fn NativeBridgeLoopDelivery::result(
  self : NativeBridgeLoopDelivery,
) -> NativeBridgeLoopResult {
  self.result
}

///|
pub fn NativeBridgeLoopDelivery::evaluation_plan(
  self : NativeBridgeLoopDelivery,
) -> NativeBridgeLoopEvaluationPlan {
  self.evaluation_plan
}

///|
pub fn NativeBridgeLoopDelivery::operations(
  self : NativeBridgeLoopDelivery,
) -> Array[NativeExecutableOperation] {
  self.evaluation_plan.operations()
}

///|
pub fn NativeBridgeLoopDelivery::is_empty(
  self : NativeBridgeLoopDelivery,
) -> Bool {
  self.evaluation_plan.is_empty()
}

///|
pub fn NativeBridgeLoopDelivery::to_json(
  self : NativeBridgeLoopDelivery,
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
pub fn NativeBridgeLoopResult::to_json(self : NativeBridgeLoopResult) -> String {
  [
    "{",
    "\"immediateScript\":\{self.immediate_script.json_string()},",
    "\"completions\":[\{self.completions.map(fn(completion) { completion.to_json() }).join(",")}],",
    "\"evaluationScripts\":[\{self.evaluation_scripts().map(fn(script) { script.json_string() }).join(",")}]",
    "}",
  ].join("")
}

///|
pub fn NativeBridgeDispatch::window_label(
  self : NativeBridgeDispatch,
) -> String {
  self.window_label
}

///|
pub fn NativeBridgeDispatch::response_hook(
  self : NativeBridgeDispatch,
) -> String {
  self.response_hook
}

///|
pub fn NativeBridgeDispatch::message(self : NativeBridgeDispatch) -> String {
  self.message
}

///|
pub fn NativeBridgeDispatch::response_json(
  self : NativeBridgeDispatch,
) -> String {
  self.response_json
}

///|
pub fn NativeBridgeDispatch::evaluation_script(
  self : NativeBridgeDispatch,
) -> String {
  self.evaluation_script
}

///|
pub fn NativeBridgeDispatch::to_json(self : NativeBridgeDispatch) -> String {
  [
    "{",
    "\"windowLabel\":\{self.window_label.json_string()},",
    "\"responseHook\":\{self.response_hook.json_string()},",
    "\"message\":\{self.message.json_string()},",
    "\"responseJson\":\{self.response_json.json_string()},",
    "\"evaluationScript\":\{self.evaluation_script.json_string()}",
    "}",
  ].join("")
}

///|
pub fn native_bridge_response_script(
  response_hook : String,
  response_json : String,
) -> String {
  "globalThis[\{response_hook.js_string_literal()}](\{response_json});"
}

///|
pub fn native_webkit_bridge_hook_script(
  hook : String,
  platform_name~ : String,
) -> String {
  native_bridge_hook_script(hook, post_message_lines=[
    "      const handler = globalThis.webkit && globalThis.webkit.messageHandlers && globalThis.webkit.messageHandlers[nativeHook];",
    "      if (!handler || typeof handler.postMessage !== \"function\") {",
    "        reject(new Error(`\{missing_bridge_message("Missing Lepusa \{platform_name} native message handler")}: ${nativeHook}`));",
    "        return;",
    "      }",
    "      pending.set(String(request.id || \"\"), { resolve, reject });",
    "      handler.postMessage(JSON.stringify(request));",
  ])
}

///|
pub fn native_webview2_bridge_hook_script(hook : String) -> String {
  native_bridge_hook_script(hook, post_message_lines=[
    "      const chrome = globalThis.chrome;",
    "      const webview = chrome && chrome.webview;",
    "      if (!webview || typeof webview.postMessage !== \"function\") {",
    "        reject(new Error(`\{missing_bridge_message("Missing Lepusa Windows WebView2 bridge")}: ${nativeHook}`));",
    "        return;",
    "      }",
    "      pending.set(String(request.id || \"\"), { resolve, reject });",
    "      webview.postMessage(JSON.stringify({ hook: nativeHook, request }));",
  ])
}

///|
fn native_bridge_hook_script(
  hook : String,
  post_message_lines~ : Array[String],
) -> String {
  let native_hook = hook.js_string_literal()
  let response_hook = "\{hook}Response".js_string_literal()
  let lines = [
    "(() => {",
    "  const nativeHook = \{native_hook};",
    "  const responseHook = \{response_hook};",
    "  const pending = new Map();",
    "  Object.defineProperty(globalThis, responseHook, {",
    "    value: (response) => {",
    "      const id = response && String(response.id || \"\");",
    "      const callbacks = pending.get(id);",
    "      if (!callbacks) { return false; }",
    "      pending.delete(id);",
    "      if (response && response.error) { callbacks.reject(new Error(response.error)); }",
    "      else { callbacks.resolve(response || null); }",
    "      return true;",
    "    },",
    "    configurable: true,",
    "  });",
    "  Object.defineProperty(globalThis, nativeHook, {",
    "    value: (request) => new Promise((resolve, reject) => {",
  ]
  for line in post_message_lines {
    lines.push(line)
  }
  for line in ["    }),", "    configurable: true,", "  });", "})();"] {
    lines.push(line)
  }
  lines.join("\n")
}

///|
fn missing_bridge_message(message : String) -> String {
  message.replace_all(old="`", new="'")
}

///|
fn bridge_window_label_from_message(
  message : String,
  window_label~ : String,
) -> String {
  if window_label != "" {
    window_label
  } else {
    match decode_invoke_request_json(message) {
      Ok(request) => request.window_label()
      Err(_) => ""
    }
  }
}

///|
fn String::js_string_literal(self : String) -> String {
  "\"" +
  self
  .replace_all(old="\\", new="\\\\")
  .replace_all(old="\"", new="\\\"")
  .replace_all(old="\n", new="\\n")
  .replace_all(old="\r", new="\\r")
  .replace_all(old="\t", new="\\t") +
  "\""
}
