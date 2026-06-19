///|
pub struct FrontendEventDispatch {
  window_label : String
  hook : String
  event : Event
  script : String
} derive(Debug, Eq)

///|
pub fn FrontendEventDispatch::new(
  window_label~ : String,
  hook? : String = "__lepusaDispatchEvent",
  event~ : Event,
) -> FrontendEventDispatch {
  { window_label, hook, event, script: frontend_event_script(hook, event) }
}

///|
pub fn FrontendEventDispatch::window_label(
  self : FrontendEventDispatch,
) -> String {
  self.window_label
}

///|
pub fn FrontendEventDispatch::hook(self : FrontendEventDispatch) -> String {
  self.hook
}

///|
pub fn FrontendEventDispatch::event(self : FrontendEventDispatch) -> Event {
  self.event
}

///|
pub fn FrontendEventDispatch::script(self : FrontendEventDispatch) -> String {
  self.script
}

///|
pub fn FrontendEventDispatch::to_json(self : FrontendEventDispatch) -> String {
  [
    "{",
    "\"windowLabel\":\{self.window_label.json_string()},",
    "\"hook\":\{self.hook.json_string()},",
    "\"event\":\{self.event.to_json()},",
    "\"script\":\{self.script.json_string()}",
    "}",
  ].join("")
}

///|
fn frontend_event_script(hook : String, event : Event) -> String {
  [
    "(() => {",
    "  const hook = globalThis[\{hook.json_string()}];",
    "  if (typeof hook !== \"function\") {",
    "    throw new Error(\"Missing Lepusa event dispatch hook: \{hook}\");",
    "  }",
    "  return hook(\{event.to_json()});",
    "})()",
  ].join("\n")
}
