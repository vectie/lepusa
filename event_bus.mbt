///|
pub struct EventListener {
  id : String
  name : String
  target : EventTarget
  once : Bool
} derive(Debug, Eq)

///|
pub struct EventDelivery {
  listener_id : String
  target : EventTarget
  event : Event
} derive(Debug, Eq)

///|
pub struct EventBus {
  mut next_listener_sequence : Int
  listeners : Map[String, EventListener]
  order : Array[String]
}

///|
pub fn EventTarget::kind(self : EventTarget) -> String {
  match self {
    AppTarget => "app"
    WindowTarget(_) => "window"
    WebviewTarget(_) => "webview"
  }
}

///|
pub fn EventTarget::label(self : EventTarget) -> String? {
  match self {
    AppTarget => None
    WindowTarget(label) | WebviewTarget(label) => Some(label)
  }
}

///|
pub fn EventTarget::validate(self : EventTarget) -> Array[String] {
  let problems : Array[String] = []
  match self {
    AppTarget => ()
    WindowTarget(label) =>
      if label == "" {
        problems.push("event target window label is required")
      }
    WebviewTarget(label) =>
      if label == "" {
        problems.push("event target webview label is required")
      }
  }
  problems
}

///|
pub fn EventListener::id(self : EventListener) -> String {
  self.id
}

///|
pub fn EventListener::name(self : EventListener) -> String {
  self.name
}

///|
pub fn EventListener::target(self : EventListener) -> EventTarget {
  self.target
}

///|
pub fn EventListener::once(self : EventListener) -> Bool {
  self.once
}

///|
pub fn EventListener::to_json(self : EventListener) -> String {
  [
    "{",
    "\"id\":\{self.id.json_string()},",
    "\"name\":\{self.name.json_string()},",
    "\"target\":\{self.target.to_json()},",
    "\"once\":\{self.once.json_bool()}",
    "}",
  ].join("")
}

///|
pub fn EventDelivery::listener_id(self : EventDelivery) -> String {
  self.listener_id
}

///|
pub fn EventDelivery::target(self : EventDelivery) -> EventTarget {
  self.target
}

///|
pub fn EventDelivery::event(self : EventDelivery) -> Event {
  self.event
}

///|
pub fn EventDelivery::to_json(self : EventDelivery) -> String {
  [
    "{",
    "\"listenerId\":\{self.listener_id.json_string()},",
    "\"target\":\{self.target.to_json()},",
    "\"event\":\{self.event.to_json()}",
    "}",
  ].join("")
}

///|
pub fn EventBus::new() -> EventBus {
  { next_listener_sequence: 1, listeners: {}, order: [] }
}

///|
pub fn EventBus::listen(
  self : EventBus,
  name : String,
  target? : EventTarget = AppTarget,
  once? : Bool = false,
) -> Result[EventListener, Array[String]] {
  let problems = event_listener_problems(name, target)
  if !problems.is_empty() {
    return Err(problems)
  }
  let sequence = self.next_listener_sequence
  self.next_listener_sequence += 1
  let id = "listener-\{sequence}"
  let listener = { id, name, target, once }
  self.listeners[id] = listener
  self.order.push(id)
  Ok(listener)
}

///|
pub fn EventBus::once(
  self : EventBus,
  name : String,
  target? : EventTarget = AppTarget,
) -> Result[EventListener, Array[String]] {
  self.listen(name, target~, once=true)
}

///|
pub fn EventBus::listener(self : EventBus, id : String) -> EventListener? {
  self.listeners.get(id)
}

///|
pub fn EventBus::listeners(self : EventBus) -> Array[EventListener] {
  let listeners : Array[EventListener] = []
  for id in self.order {
    match self.listeners.get(id) {
      Some(listener) => listeners.push(listener)
      None => ()
    }
  }
  listeners
}

///|
pub fn EventBus::listener_count(self : EventBus) -> Int {
  self.listeners.length()
}

///|
pub fn EventBus::listeners_for(
  self : EventBus,
  name : String,
  target? : EventTarget = AppTarget,
) -> Array[EventListener] {
  self
  .listeners()
  .filter(fn(listener) {
    listener.name() == name && event_target_accepts(listener.target(), target)
  })
}

///|
pub fn EventBus::emit(
  self : EventBus,
  event : Event,
  target? : EventTarget = AppTarget,
) -> Result[Array[EventDelivery], Array[String]] {
  let problems = event.validate()
  for problem in target.validate() {
    problems.push(problem)
  }
  if !problems.is_empty() {
    return Err(problems)
  }
  let deliveries : Array[EventDelivery] = []
  let once_ids : Array[String] = []
  for listener in self.listeners() {
    if listener.name() == event.name() &&
      event_target_accepts(listener.target(), target) {
      deliveries.push({ listener_id: listener.id(), target, event })
      if listener.once() {
        once_ids.push(listener.id())
      }
    }
  }
  for id in once_ids {
    ignore(self.unlisten(id))
  }
  Ok(deliveries)
}

///|
pub fn EventBus::unlisten(
  self : EventBus,
  id : String,
) -> Result[EventListener, String] {
  match self.listeners.get(id) {
    Some(listener) => {
      self.listeners.remove(id)
      self.remove_ordered_listener(id)
      Ok(listener)
    }
    None => Err("event listener not found: \{id}")
  }
}

///|
pub fn EventBus::remove_target(
  self : EventBus,
  target : EventTarget,
) -> Array[EventListener] {
  let removed : Array[EventListener] = []
  for listener in self.listeners() {
    if listener.target() == target {
      match self.unlisten(listener.id()) {
        Ok(removed_listener) => removed.push(removed_listener)
        Err(_) => ()
      }
    }
  }
  removed
}

///|
pub fn EventBus::clear(self : EventBus) -> Array[EventListener] {
  let listeners = self.listeners()
  self.listeners.clear()
  self.order.clear()
  listeners
}

///|
pub fn EventBus::to_json(self : EventBus) -> String {
  [
    "{",
    "\"nextListenerSequence\":\{self.next_listener_sequence},",
    "\"listeners\":[\{self.listeners().map(fn(listener) { listener.to_json() }).join(",")}]",
    "}",
  ].join("")
}

///|
fn event_listener_problems(
  name : String,
  target : EventTarget,
) -> Array[String] {
  let problems = Event::new(name).validate()
  for problem in target.validate() {
    problems.push(problem)
  }
  problems
}

///|
fn event_target_accepts(
  listener_target : EventTarget,
  emit_target : EventTarget,
) -> Bool {
  emit_target is AppTarget ||
  listener_target is AppTarget ||
  listener_target == emit_target
}

///|
fn EventBus::remove_ordered_listener(self : EventBus, id : String) -> Unit {
  match self.order.search(id) {
    Some(index) => ignore(self.order.remove(index))
    None => ()
  }
}
