///|
pub struct BundledLifecycleEvent {
  kind : String
  label : String
} derive(Debug, Eq)

///|
pub fn BundledLifecycleEvent::app_started() -> BundledLifecycleEvent {
  { kind: "app-started", label: "" }
}

///|
pub fn BundledLifecycleEvent::app_will_exit() -> BundledLifecycleEvent {
  { kind: "app-will-exit", label: "" }
}

///|
pub fn BundledLifecycleEvent::window_close_requested(
  label : String,
) -> Result[BundledLifecycleEvent, String] {
  if label == "" {
    Err("lifecycle window is required")
  } else {
    Ok({ kind: "window-close-requested", label })
  }
}

///|
pub fn BundledLifecycleEvent::window_closed(
  label : String,
) -> Result[BundledLifecycleEvent, String] {
  if label == "" {
    Err("lifecycle window is required")
  } else {
    Ok({ kind: "window-closed", label })
  }
}

///|
pub fn BundledLifecycleEvent::kind(self : BundledLifecycleEvent) -> String {
  self.kind
}

///|
pub fn BundledLifecycleEvent::label(self : BundledLifecycleEvent) -> String {
  self.label
}

///|
pub fn BundledRuntimeManifest::lifecycle_json(
  self : BundledRuntimeManifest,
  event : BundledLifecycleEvent,
) -> String {
  let actions = if event.kind == "app-started" {
    optional_array(self.runtime, "startupActions").unwrap_or([])
  } else {
    self.lifecycle_actions_for_event(event)
  }
  let services = if event.kind == "app-started" {
    optional_array(self.runtime, "localServices").unwrap_or([])
  } else {
    []
  }
  [
    "{",
    "\"event\":\{runtime_lifecycle_event_json(event)},",
    "\"localServices\":\{json_array_string(services)},",
    "\"actions\":\{json_array_string(actions)}",
    "}",
  ].join("")
}

///|
fn BundledRuntimeManifest::lifecycle_actions_for_event(
  self : BundledRuntimeManifest,
  event : BundledLifecycleEvent,
) -> Array[Json] {
  for item in optional_array(self.runtime, "lifecycleHooks").unwrap_or([]) {
    match item {
      Object(hook) =>
        match optional_object(hook, "event") {
          Some(hook_event) =>
            if runtime_lifecycle_event_matches(hook_event, event) {
              return optional_array(hook, "actions").unwrap_or([])
            }
          None => ()
        }
      _ => ()
    }
  }
  []
}

///|
fn runtime_lifecycle_event_matches(
  object : Map[String, Json],
  event : BundledLifecycleEvent,
) -> Bool {
  optional_string(object, "kind").unwrap_or("") == event.kind &&
  optional_string(object, "label").unwrap_or("") == event.label
}

///|
fn runtime_lifecycle_event_json(event : BundledLifecycleEvent) -> String {
  if event.label == "" {
    "{\"kind\":\{event.kind.json_string()}}"
  } else {
    [
      "{",
      "\"kind\":\{event.kind.json_string()},",
      "\"label\":\{event.label.json_string()}",
      "}",
    ].join("")
  }
}
