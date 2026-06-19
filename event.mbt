///|
pub(all) enum EventTarget {
  AppTarget
  WindowTarget(String)
  WebviewTarget(String)
} derive(Debug, Eq)

///|
pub struct Event {
  name : String
  payload : String
} derive(Debug, Eq)

///|
pub fn Event::new(name : String, payload? : String = "") -> Event {
  { name, payload }
}

///|
pub fn Event::name(self : Event) -> String {
  self.name
}

///|
pub fn Event::payload(self : Event) -> String {
  self.payload
}

///|
pub fn Event::validate(self : Event) -> Array[String] {
  let problems : Array[String] = []
  if self.name == "" {
    problems.push("event name is required")
  }
  problems
}
