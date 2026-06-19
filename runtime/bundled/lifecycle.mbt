///|
pub struct BundledLifecycleEvent {
  kind : String
  label : String
} derive(Debug, Eq)

///|
pub struct BundledLifecyclePlan {
  event : BundledLifecycleEvent
  action_jsons : Array[String]
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
pub fn BundledRuntimeManifest::local_service_jsons(
  self : BundledRuntimeManifest,
) -> Array[String] {
  optional_array(self.runtime, "localServices")
  .unwrap_or([])
  .map(json_value_string)
}

///|
pub fn BundledRuntimeManifest::startup_action_jsons(
  self : BundledRuntimeManifest,
) -> Array[String] {
  optional_array(self.runtime, "startupActions")
  .unwrap_or([])
  .map(json_value_string)
}

///|
pub fn BundledRuntimeManifest::lifecycle_plans(
  self : BundledRuntimeManifest,
) -> Result[Array[BundledLifecyclePlan], String] {
  let plans : Array[BundledLifecyclePlan] = []
  for item in optional_array(self.runtime, "lifecycleHooks").unwrap_or([]) {
    match item {
      Object(hook) =>
        match bundled_lifecycle_plan_from_json(hook) {
          Ok(plan) => plans.push(plan)
          Err(problem) => return Err(problem)
        }
      _ => return Err("runtime lifecycle hook must be a json object")
    }
  }
  Ok(plans)
}

///|
pub fn BundledLifecyclePlan::event(
  self : BundledLifecyclePlan,
) -> BundledLifecycleEvent {
  self.event
}

///|
pub fn BundledLifecyclePlan::action_jsons(
  self : BundledLifecyclePlan,
) -> Array[String] {
  self.action_jsons.copy()
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
fn bundled_lifecycle_plan_from_json(
  hook : Map[String, Json],
) -> Result[BundledLifecyclePlan, String] {
  match optional_object(hook, "event") {
    Some(event_json) =>
      match bundled_lifecycle_event_from_json(event_json) {
        Ok(event) =>
          Ok({
            event,
            action_jsons: optional_array(hook, "actions")
            .unwrap_or([])
            .map(json_value_string),
          })
        Err(problem) => Err(problem)
      }
    None => Err("runtime lifecycle hook event is required")
  }
}

///|
fn bundled_lifecycle_event_from_json(
  object : Map[String, Json],
) -> Result[BundledLifecycleEvent, String] {
  match optional_string(object, "kind") {
    Some("app-started") => Ok(BundledLifecycleEvent::app_started())
    Some("app-will-exit") => Ok(BundledLifecycleEvent::app_will_exit())
    Some("window-close-requested") =>
      BundledLifecycleEvent::window_close_requested(
        optional_string(object, "label").unwrap_or(""),
      )
    Some("window-closed") =>
      BundledLifecycleEvent::window_closed(
        optional_string(object, "label").unwrap_or(""),
      )
    Some(kind) => Err("unsupported runtime lifecycle event: \{kind}")
    None => Err("runtime lifecycle event kind is required")
  }
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
