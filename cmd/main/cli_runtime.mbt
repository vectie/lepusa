///|
async fn render_manifest_async(args : Array[String]) -> CliResult {
  match project_runtime_host(args) {
    Ok(host) =>
      match host.launch_manifest() {
        Ok(manifest) => ok(manifest.to_json() + "\n")
        Err(problems) => fail(render_problems("Lepusa manifest", problems))
      }
    Err(problems) => fail(render_problems("Lepusa manifest", problems))
  }
}

///|
async fn render_plan_async(args : Array[String]) -> CliResult {
  match project_runtime_plan(args) {
    Ok(plan) => render_runtime_plan(plan)
    Err(problems) => fail(render_problems("Lepusa runtime plan", problems))
  }
}

///|
async fn render_bridge_async(args : Array[String]) -> CliResult {
  match project_runtime_plan(args) {
    Ok(plan) =>
      match plan.bridge_script() {
        Ok(script) => ok(script.source())
        Err(problems) => fail(render_problems("Lepusa bridge", problems))
      }
    Err(problems) => fail(render_problems("Lepusa bridge", problems))
  }
}

///|
async fn render_dev_async(args : Array[String]) -> CliResult {
  match project_runtime_host(args) {
    Ok(host) =>
      match host.dev_plan() {
        Ok(dev) => render_dev_plan(dev)
        Err(problems) => fail(render_problems("Lepusa dev", problems))
      }
    Err(problems) => fail(render_problems("Lepusa dev", problems))
  }
}

///|
async fn render_lifecycle_async(args : Array[String]) -> CliResult {
  let values = positional_args(args)
  match parse_lifecycle_event_args(values) {
    Ok(event) =>
      match project_runtime_host(args) {
        Ok(host) =>
          match host.runner_plan() {
            Ok(plan) => ok(plan.lifecycle_step(event).to_json() + "\n")
            Err(problems) => fail(render_problems("Lepusa lifecycle", problems))
          }
        Err(problems) => fail(render_problems("Lepusa lifecycle", problems))
      }
    Err(problem) => fail(problem + "\n")
  }
}

///|
fn parse_lifecycle_event_args(
  values : Array[String],
) -> Result[@lepusa.LifecycleEvent, String] {
  match values.get(0) {
    None => Err("lifecycle event is required")
    Some("app-started") => Ok(@lepusa.LifecycleEvent::app_started())
    Some("app-will-exit") => Ok(@lepusa.LifecycleEvent::app_will_exit())
    Some("window-close-requested") =>
      match values.get(1) {
        Some(label) if label != "" =>
          Ok(@lepusa.LifecycleEvent::window_close_requested(label))
        _ => Err("lifecycle window is required")
      }
    Some("window-closed") =>
      match values.get(1) {
        Some(label) if label != "" =>
          Ok(@lepusa.LifecycleEvent::window_closed(label))
        _ => Err("lifecycle window is required")
      }
    Some(value) => Err("unknown lifecycle event: \{value}")
  }
}

///|
async fn render_asset_async(args : Array[String]) -> CliResult {
  let values = positional_args(args)
  let url = values.get(0).unwrap_or("")
  if url == "" {
    return fail("asset url is required\n")
  }
  match project_runtime_host(args) {
    Ok(host) => ok(host.resolve_asset_json(url) + "\n")
    Err(problems) => fail(render_problems("Lepusa asset", problems))
  }
}

///|
async fn render_bridge_task_async(args : Array[String]) -> CliResult {
  let values = positional_args(args)
  let window_label = values.get(0).unwrap_or("")
  let route = values.get(1).unwrap_or("")
  let payload = values.get(2).unwrap_or("")
  if window_label == "" {
    return fail("bridge-task window is required\n")
  }
  match parse_command_route(route, command_name="bridge-task") {
    Ok((plugin, command)) =>
      match project_runtime_host(args) {
        Ok(host) => {
          let request = @lepusa.InvokeRequest::new(
            id="cli",
            window_label~,
            plugin~,
            command~,
            payload~,
          )
          let message = @runtime.encode_invoke_request_json(request)
          match host.bridge_dispatch_task(message) {
            Ok(task) => ok(task.to_json() + "\n")
            Err(problems) =>
              fail(render_problems("Lepusa bridge task", problems))
          }
        }
        Err(problems) => fail(render_problems("Lepusa bridge task", problems))
      }
    Err(problem) => fail(problem + "\n")
  }
}

///|
async fn render_bridge_dispatch_async(args : Array[String]) -> CliResult {
  let values = positional_args(args)
  let window_label = values.get(0).unwrap_or("")
  let route = values.get(1).unwrap_or("")
  let payload = values.get(2).unwrap_or("")
  if window_label == "" {
    return fail("bridge-dispatch window is required\n")
  }
  match parse_command_route(route, command_name="bridge-dispatch") {
    Ok((plugin, command)) =>
      match project_runtime_host(args) {
        Ok(host) => {
          let request = @lepusa.InvokeRequest::new(
            id="cli",
            window_label~,
            plugin~,
            command~,
            payload~,
          )
          let message = @runtime.encode_invoke_request_json(request)
          match host.dispatch_bridge_message(message, window_label~) {
            Ok(dispatch) => ok(dispatch.to_json() + "\n")
            Err(problems) =>
              fail(render_problems("Lepusa bridge dispatch", problems))
          }
        }
        Err(problems) =>
          fail(render_problems("Lepusa bridge dispatch", problems))
      }
    Err(problem) => fail(problem + "\n")
  }
}

///|
async fn render_invoke_async(args : Array[String]) -> CliResult {
  let values = positional_args(args)
  let window_label = values.get(0).unwrap_or("")
  let route = values.get(1).unwrap_or("")
  let payload = values.get(2).unwrap_or("")
  if window_label == "" {
    return fail("invoke window is required\n")
  }
  match parse_invoke_route(route) {
    Ok((plugin, command)) =>
      match project_runtime_host(args) {
        Ok(host) => {
          let request = @lepusa.InvokeRequest::new(
            id="cli",
            window_label~,
            plugin~,
            command~,
            payload~,
          )
          ok(
            @runtime.encode_invoke_response_json(host.dispatch_async(request)) +
            "\n",
          )
        }
        Err(problems) => fail(render_problems("Lepusa invoke", problems))
      }
    Err(problem) => fail(problem + "\n")
  }
}

///|
fn parse_invoke_route(route : String) -> Result[(String, String), String] {
  parse_command_route(route, command_name="invoke")
}

///|
fn parse_command_route(
  route : String,
  command_name~ : String,
) -> Result[(String, String), String] {
  let mut plugin = ""
  let mut command = ""
  let mut found_separator = false
  for char in route {
    if !found_separator && char == '.' {
      found_separator = true
    } else if found_separator {
      command = command + char.to_string()
    } else {
      plugin = plugin + char.to_string()
    }
  }
  if plugin == "" || command == "" {
    return Err("\{command_name} route must be <plugin.command>")
  }
  Ok((plugin, command))
}

///|
fn render_runtime_plan(plan : @lepusa.RuntimePlan) -> CliResult {
  let routes = plan.command_routes().join(",")
  let first_window = match plan.windows().get(0) {
    Some(window) => window.url()
    None => ""
  }
  ok(
    "Lepusa runtime plan\n" +
    "backend: \{plan.backend().name()}\n" +
    "windows: \{plan.window_count()}\n" +
    "first-window-url: \{first_window}\n" +
    "plugins: \{plan.plugin_count()}\n" +
    "capabilities: \{plan.capability_count()}\n" +
    "filesystem-scopes: \{plan.file_system_scopes().length()}\n" +
    "routes: \{routes}\n",
  )
}

///|
fn render_dev_plan(dev : @runtime.RuntimeDevPlan) -> CliResult {
  let session = dev.session()
  let services = dev.service_plan()
  let routes = session.command_routes().join(",")
  let registered_routes = session.registered_routes().join(",")
  let first_window = match dev.webviews().get(0) {
    Some(window) => window.url()
    None => ""
  }
  ok(
    "Lepusa dev plan\n" +
    "backend: \{session.backend().name()}\n" +
    "webviews: \{dev.webviews().length()}\n" +
    "first-window-url: \{first_window}\n" +
    "asset-protocol: \{session.asset_protocol()}\n" +
    "routes: \{routes}\n" +
    "registered-routes: \{registered_routes}\n" +
    "local-services: \{services.services().length()}\n" +
    "service-supervisor: \{services.requires_supervisor()}\n" +
    "service-start-order: \{services.startup_service_names().join(",")}\n" +
    "filesystem-scopes: \{session.file_system_scopes().length()}\n" +
    "startup-operations: \{dev.startup_operations().length()}\n",
  )
}
