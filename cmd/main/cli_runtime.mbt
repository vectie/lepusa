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
        Ok(dev) =>
          if has_flag(args, "--json") {
            ok(dev.to_json() + "\n")
          } else {
            render_dev_plan(dev, args)
          }
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
    Some("plugin-setup") =>
      match values.get(1) {
        Some(name) if name != "" =>
          Ok(@lepusa.LifecycleEvent::plugin_setup(name))
        _ => Err("lifecycle plugin is required")
      }
    Some("plugin-ready") =>
      match values.get(1) {
        Some(name) if name != "" =>
          Ok(@lepusa.LifecycleEvent::plugin_ready(name))
        _ => Err("lifecycle plugin is required")
      }
    Some("plugin-will-exit") =>
      match values.get(1) {
        Some(name) if name != "" =>
          Ok(@lepusa.LifecycleEvent::plugin_will_exit(name))
        _ => Err("lifecycle plugin is required")
      }
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
async fn render_bridge_handoff_async(args : Array[String]) -> CliResult {
  let values = positional_args(args)
  let window_label = values.get(0).unwrap_or("")
  let route = values.get(1).unwrap_or("")
  let payload = values.get(2).unwrap_or("")
  if window_label == "" {
    return fail("bridge-handoff window is required\n")
  }
  match parse_command_route(route, command_name="bridge-handoff") {
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
          match host.bridge_handoff(message, window_label~) {
            Ok(handoff) => ok(handoff.to_json() + "\n")
            Err(problems) =>
              fail(render_problems("Lepusa bridge handoff", problems))
          }
        }
        Err(problems) =>
          fail(render_problems("Lepusa bridge handoff", problems))
      }
    Err(problem) => fail(problem + "\n")
  }
}

///|
async fn render_bridge_complete_async(args : Array[String]) -> CliResult {
  let values = positional_args(args)
  let window_label = values.get(0).unwrap_or("")
  let route = values.get(1).unwrap_or("")
  let payload = values.get(2).unwrap_or("")
  if window_label == "" {
    return fail("bridge-complete window is required\n")
  }
  match parse_command_route(route, command_name="bridge-complete") {
    Ok((plugin, command)) =>
      match project_runtime_host(args) {
        Ok(host) =>
          match
            @runtime.NativeRuntime::new(
              @runtime.NativeBackend::new(
                name="cli",
                webview_engine="SystemWebView",
              ),
              host,
            ) {
            Ok(runtime) => {
              let request = @lepusa.InvokeRequest::new(
                id="cli",
                window_label~,
                plugin~,
                command~,
                payload~,
              )
              let message = @runtime.encode_invoke_request_json(request)
              match runtime.bridge_handoff(message, window_label~) {
                Ok(handoff) =>
                  match handoff.complete_deferred(runtime) {
                    Ok(completion) => ok(completion.to_json() + "\n")
                    Err(problem) =>
                      fail("Lepusa bridge complete\n[fail] \{problem}\n")
                  }
                Err(problems) =>
                  fail(render_problems("Lepusa bridge complete", problems))
              }
            }
            Err(problems) =>
              fail(render_problems("Lepusa bridge complete", problems))
          }
        Err(problems) =>
          fail(render_problems("Lepusa bridge complete", problems))
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
async fn render_bridge_loop_async(args : Array[String]) -> CliResult {
  let values = positional_args(args)
  let window_label = values.get(0).unwrap_or("")
  let route = values.get(1).unwrap_or("")
  let payload = values.get(2).unwrap_or("")
  if window_label == "" {
    return fail("bridge-loop window is required\n")
  }
  match parse_command_route(route, command_name="bridge-loop") {
    Ok((plugin, command)) =>
      match project_runtime_host(args) {
        Ok(host) =>
          match
            @runtime.NativeRuntime::new(
              @runtime.NativeBackend::new(
                name="cli",
                webview_engine="SystemWebView",
              ),
              host,
            ) {
            Ok(runtime) => {
              let request = @lepusa.InvokeRequest::new(
                id="cli",
                window_label~,
                plugin~,
                command~,
                payload~,
              )
              let message = @runtime.encode_invoke_request_json(request)
              let delivery = runtime
                .bridge_loop_adapter()
                .receive_window_message(window_label~, @utf8.encode(message))
              ok(delivery.to_json() + "\n")
            }
            Err(problems) =>
              fail(render_problems("Lepusa bridge loop", problems))
          }
        Err(problems) => fail(render_problems("Lepusa bridge loop", problems))
      }
    Err(problem) => fail(problem + "\n")
  }
}

///|
async fn render_bridge_drain_async(args : Array[String]) -> CliResult {
  let values = positional_args(args)
  let window_label = values.get(0).unwrap_or("")
  let route = values.get(1).unwrap_or("")
  let payload = values.get(2).unwrap_or("")
  if window_label == "" {
    return fail("bridge-drain window is required\n")
  }
  match parse_command_route(route, command_name="bridge-drain") {
    Ok((plugin, command)) =>
      match project_runtime_host(args) {
        Ok(host) =>
          match
            @runtime.NativeRuntime::new(
              @runtime.NativeBackend::new(
                name="cli",
                webview_engine="SystemWebView",
              ),
              host,
            ) {
            Ok(runtime) => {
              let request = @lepusa.InvokeRequest::new(
                id="cli",
                window_label~,
                plugin~,
                command~,
                payload~,
              )
              let message = @runtime.encode_invoke_request_json(request)
              let adapter = runtime.bridge_loop_adapter()
              let handoff_script = @utf8.decode(
                adapter.handoff_callback()(@utf8.encode(message)),
              ) catch {
                _ => ""
              }
              let pending_after_handoff = adapter.pending_count()
              let delivery = adapter.drain_window(window_label~)
              ok(
                render_bridge_drain_json(
                  handoff_script,
                  pending_after_handoff~,
                  delivery_json=delivery.to_json(),
                  pending_after_drain=adapter.pending_count(),
                ) +
                "\n",
              )
            }
            Err(problems) =>
              fail(render_problems("Lepusa bridge drain", problems))
          }
        Err(problems) => fail(render_problems("Lepusa bridge drain", problems))
      }
    Err(problem) => fail(problem + "\n")
  }
}

///|
fn render_bridge_drain_json(
  handoff_script : String,
  pending_after_handoff~ : Int,
  delivery_json~ : String,
  pending_after_drain~ : Int,
) -> String {
  [
    "{",
    "\"handoffScript\":\{cli_json_string(handoff_script)},",
    "\"pendingAfterHandoff\":\{pending_after_handoff},",
    "\"delivery\":\{delivery_json},",
    "\"pendingAfterDrain\":\{pending_after_drain}",
    "}",
  ].join("")
}

///|
fn cli_json_string(value : String) -> String {
  let mut out = "\""
  for ch in value {
    match ch {
      '"' => out += "\\\""
      '\\' => out += "\\\\"
      '\n' => out += "\\n"
      '\r' => out += "\\r"
      '\t' => out += "\\t"
      _ => out += ch.to_string()
    }
  }
  out + "\""
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
fn render_dev_plan(
  dev : @runtime.RuntimeDevPlan,
  args : Array[String],
) -> CliResult {
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
    "bridge-sync-routes: \{dev.bridge_sync_routes().length()}\n" +
    "bridge-async-routes: \{dev.bridge_async_routes().length()}\n" +
    "local-services: \{services.services().length()}\n" +
    "service-supervisor: \{services.requires_supervisor()}\n" +
    "service-start-order: \{services.startup_service_names().join(",")}\n" +
    "filesystem-scopes: \{session.file_system_scopes().length()}\n" +
    "startup-operations: \{dev.startup_operations().length()}\n" +
    "lifecycle-steps: \{dev.lifecycle_steps().length()}\n" +
    render_dev_commands(dev, args),
  )
}

///|
fn render_dev_commands(
  dev : @runtime.RuntimeDevPlan,
  args : Array[String],
) -> String {
  let project = render_dev_project_suffix(args)
  let lines : Array[String] = ["commands:\n"]
  for command in dev.commands() {
    if command.target_required() {
      for target in ["macos", "linux", "windows"] {
        lines.push(
          "  \{command.name()}:\{target}: \{render_dev_command(command, target, project)}\n",
        )
      }
    } else {
      lines.push(
        "  \{command.name()}: \{render_dev_command(command, "", project)}\n",
      )
    }
  }
  lines.join("")
}

///|
fn render_dev_command(
  command : @runtime.RuntimeDevCommand,
  target : String,
  project : String,
) -> String {
  command
  .template()
  .replace_all(old="{target}", new=target)
  .replace_all(old="{project}", new=project)
}

///|
fn render_dev_project_suffix(args : Array[String]) -> String {
  match project_path_arg(args) {
    Some(path) => " --project \{shell_arg(path)}"
    None => ""
  }
}

///|
fn shell_arg(value : String) -> String {
  if value == "" {
    return "''"
  }
  let mut safe = true
  for char in value {
    if !(char >= 'a' && char <= 'z') &&
      !(char >= 'A' && char <= 'Z') &&
      !(char >= '0' && char <= '9') &&
      char != '/' &&
      char != '.' &&
      char != '_' &&
      char != '-' {
      safe = false
    }
  }
  if safe {
    value
  } else {
    "'" + value.replace_all(old="'", new="'\\''") + "'"
  }
}
