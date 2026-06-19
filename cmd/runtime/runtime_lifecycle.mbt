///|
async fn render_runtime_lifecycle(args : Array[String]) -> RuntimeCliResult {
  match runtime_lifecycle_event_arg(args) {
    Ok(event) =>
      match runtime_manifest_path(args) {
        Ok(path) => {
          let text = @fs.read_file(path).text() catch {
            error =>
              return runtime_fail(
                "Lepusa runtime lifecycle\n[fail] could not read manifest \{path}: \{error}\n",
              )
          }
          render_runtime_lifecycle_text(text, event)
        }
        Err(problem) => runtime_fail(problem + "\n")
      }
    Err(problem) => runtime_fail(problem + "\n")
  }
}

///|
fn render_runtime_lifecycle_text(
  text : String,
  event : RuntimeLifecycleEventArg,
) -> RuntimeCliResult {
  let json = @json.parse(text) catch {
    error =>
      return runtime_fail(
        "Lepusa runtime lifecycle\n[fail] invalid runtime json: \{error}\n",
      )
  }
  match json {
    Object(object) =>
      match optional_object(object, "runtime") {
        Some(runtime) =>
          runtime_ok(runtime_lifecycle_step_json(runtime, event) + "\n")
        None =>
          runtime_fail(
            "Lepusa runtime lifecycle\n[fail] runtime object is required\n",
          )
      }
    _ =>
      runtime_fail(
        "Lepusa runtime lifecycle\n[fail] runtime manifest must be a json object\n",
      )
  }
}

///|
struct RuntimeLifecycleEventArg {
  kind : String
  label : String
} derive(Debug, Eq)

///|
fn runtime_lifecycle_event_arg(
  args : Array[String],
) -> Result[RuntimeLifecycleEventArg, String] {
  match args.get(1) {
    None => Err("lifecycle event is required")
    Some("app-started") => Ok({ kind: "app-started", label: "" })
    Some("app-will-exit") => Ok({ kind: "app-will-exit", label: "" })
    Some("window-close-requested") =>
      match args.get(2) {
        Some(label) if label != "" && label != "--manifest" =>
          Ok({ kind: "window-close-requested", label })
        _ => Err("lifecycle window is required")
      }
    Some("window-closed") =>
      match args.get(2) {
        Some(label) if label != "" && label != "--manifest" =>
          Ok({ kind: "window-closed", label })
        _ => Err("lifecycle window is required")
      }
    Some(value) => Err("unknown lifecycle event: \{value}")
  }
}

///|
fn runtime_lifecycle_step_json(
  runtime : Map[String, Json],
  event : RuntimeLifecycleEventArg,
) -> String {
  let actions = if event.kind == "app-started" {
    optional_array(runtime, "startupActions").unwrap_or([])
  } else {
    lifecycle_actions_for_event(runtime, event)
  }
  let services = if event.kind == "app-started" {
    optional_array(runtime, "localServices").unwrap_or([])
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
fn lifecycle_actions_for_event(
  runtime : Map[String, Json],
  event : RuntimeLifecycleEventArg,
) -> Array[Json] {
  for item in optional_array(runtime, "lifecycleHooks").unwrap_or([]) {
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
  event : RuntimeLifecycleEventArg,
) -> Bool {
  optional_string(object, "kind").unwrap_or("") == event.kind &&
  optional_string(object, "label").unwrap_or("") == event.label
}

///|
fn runtime_lifecycle_event_json(event : RuntimeLifecycleEventArg) -> String {
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

///|
fn json_array_string(items : Array[Json]) -> String {
  "[\{items.map(json_value_string).join(",")}]"
}

///|
fn json_value_string(value : Json) -> String {
  match value {
    Null => "null"
    True => "true"
    False => "false"
    Number(value, ..) => value.to_string()
    String(value) => value.json_string()
    Array(items) => json_array_string(items)
    Object(object) => json_object_string(object)
  }
}

///|
fn json_object_string(object : Map[String, Json]) -> String {
  let keys : Array[String] = []
  for key in object.keys() {
    keys.push(key)
  }
  keys.sort()
  let fields : Array[String] = []
  for key in keys {
    match object.get(key) {
      Some(value) =>
        fields.push("\{key.json_string()}:\{json_value_string(value)}")
      None => ()
    }
  }
  "{\{fields.join(",")}}"
}
