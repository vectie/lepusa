///|
fn project_startup_from_object(
  object : Map[String, Json],
  base_dir~ : String,
  problems : Array[String],
) -> @lepusa.Cmd {
  match object.get("startup") {
    Some(json) => command_from_json(json, "startup", base_dir~, problems)
    None => @lepusa.Cmd::batch([])
  }
}

///|
fn project_lifecycle_from_object(
  object : Map[String, Json],
  base_dir~ : String,
  problems : Array[String],
) -> Array[@lepusa.LifecycleHook] {
  let hooks : Array[@lepusa.LifecycleHook] = []
  match optional_config_array(object, "lifecycle") {
    Some(items) =>
      for item in items {
        match lifecycle_hook_from_json(item, base_dir~, problems) {
          Some(hook) => hooks.push(hook)
          None => ()
        }
      }
    None => ()
  }
  hooks
}

///|
fn lifecycle_hook_from_json(
  json : Json,
  base_dir~ : String,
  problems : Array[String],
) -> @lepusa.LifecycleHook? {
  match json {
    Object(object) => {
      let event = lifecycle_event_from_object(object, problems)
      let command = match object.get("command") {
        Some(command_json) =>
          command_from_json(
            command_json,
            "lifecycle command",
            base_dir~,
            problems,
          )
        None => {
          problems.push("project lifecycle command is required")
          @lepusa.Cmd::batch([])
        }
      }
      match event {
        Some(event) => Some(@lepusa.LifecycleHook::new(event, command))
        None => None
      }
    }
    _ => {
      problems.push("project lifecycle entries must be objects")
      None
    }
  }
}

///|
fn lifecycle_event_from_object(
  object : Map[String, Json],
  problems : Array[String],
) -> @lepusa.LifecycleEvent? {
  let event = required_config_string(object, "event", problems)
  match event {
    "app-started" => Some(@lepusa.LifecycleEvent::app_started())
    "app-will-exit" => Some(@lepusa.LifecycleEvent::app_will_exit())
    "window-close-requested" =>
      Some(
        @lepusa.LifecycleEvent::window_close_requested(
          required_config_string(object, "window", problems),
        ),
      )
    "window-closed" =>
      Some(
        @lepusa.LifecycleEvent::window_closed(
          required_config_string(object, "window", problems),
        ),
      )
    value => {
      problems.push("unknown lifecycle event: \{value}")
      None
    }
  }
}

///|
fn command_from_json(
  json : Json,
  context : String,
  base_dir~ : String,
  problems : Array[String],
) -> @lepusa.Cmd {
  match json {
    Null => @lepusa.Cmd::batch([])
    String(name) => @lepusa.Cmd::effect(name)
    Array(items) => command_batch_from_json(items, context, base_dir~, problems)
    Object(object) => command_from_object(object, context, base_dir~, problems)
    _ => {
      problems.push(
        "project \{context} command must be an object, array, string, or null",
      )
      @lepusa.Cmd::batch([])
    }
  }
}

///|
fn command_batch_from_json(
  items : Array[Json],
  context : String,
  base_dir~ : String,
  problems : Array[String],
) -> @lepusa.Cmd {
  let commands : Array[@lepusa.Cmd] = []
  for item in items {
    commands.push(command_from_json(item, context, base_dir~, problems))
  }
  @lepusa.Cmd::batch(commands)
}

///|
fn command_from_object(
  object : Map[String, Json],
  context : String,
  base_dir~ : String,
  problems : Array[String],
) -> @lepusa.Cmd {
  match optional_config_string(object, "effect") {
    Some(name) => return @lepusa.Cmd::effect(name)
    None => ()
  }
  match object.get("emit") {
    Some(emit) => return emit_command_from_json(emit, problems)
    None => ()
  }
  match optional_config_object(object, "navigate") {
    Some(navigate) =>
      return navigate_command_from_object(navigate, base_dir~, problems)
    None => ()
  }
  match optional_config_array(object, "batch") {
    Some(items) =>
      return command_batch_from_json(items, context, base_dir~, problems)
    None => ()
  }
  problems.push(
    "project \{context} command object must include effect, emit, navigate, or batch",
  )
  @lepusa.Cmd::batch([])
}

///|
fn emit_command_from_json(json : Json, problems : Array[String]) -> @lepusa.Cmd {
  match json {
    String(name) => @lepusa.Cmd::emit(@lepusa.Event::new(name))
    Object(object) => {
      let name = required_config_string(object, "name", problems)
      let payload = optional_config_string(object, "payload").unwrap_or("")
      let target = match object.get("target") {
        Some(target_json) => event_target_from_json(target_json, problems)
        None => AppTarget
      }
      @lepusa.Cmd::emit(@lepusa.Event::new(name, payload~), target~)
    }
    _ => {
      problems.push("project emit command must be a string or object")
      @lepusa.Cmd::batch([])
    }
  }
}

///|
fn navigate_command_from_object(
  object : Map[String, Json],
  base_dir~ : String,
  problems : Array[String],
) -> @lepusa.Cmd {
  let window = required_config_string(object, "window", problems)
  let source = match optional_config_object(object, "source") {
    Some(source_object) =>
      source_from_object(source_object, base_dir~, problems)
    None => {
      problems.push("project navigate source is required")
      @lepusa.Source::html("<main></main>")
    }
  }
  @lepusa.Cmd::navigate(window, source)
}

///|
fn event_target_from_json(
  json : Json,
  problems : Array[String],
) -> @lepusa.EventTarget {
  match json {
    String("app") => AppTarget
    Object(object) =>
      match optional_config_string(object, "window") {
        Some(label) => WindowTarget(label)
        None =>
          match optional_config_string(object, "webview") {
            Some(label) => WebviewTarget(label)
            None => {
              problems.push(
                "project event target must include window or webview",
              )
              AppTarget
            }
          }
      }
    _ => {
      problems.push("project event target must be \"app\" or an object")
      AppTarget
    }
  }
}
