///|
struct RuntimeCliResult {
  exit_code : Int
  output : String
} derive(Debug, Eq)

///|
fn drop_program(argv : Array[String]) -> Array[String] {
  let args : Array[String] = []
  for i in 1..<argv.length() {
    args.push(argv[i])
  }
  args
}

///|
async fn render_runtime_cli_async(args : Array[String]) -> RuntimeCliResult {
  match args.get(0) {
    Some("help") | Some("--help") | Some("-h") => runtime_ok(runtime_help())
    Some("run") => render_runtime_run(args, launch=false)
    Some("launch") => render_runtime_run(args, launch=true)
    Some("bootstrap") => render_runtime_bootstrap(args)
    Some("launch-session") => render_runtime_launch_session(args)
    Some("asset") => render_runtime_asset(args)
    Some("lifecycle") => render_runtime_lifecycle(args)
    Some("bridge-task") => render_runtime_bridge_task(args)
    Some("bridge-handoff") => render_runtime_bridge_handoff(args)
    Some("bridge-complete") => render_runtime_bridge_complete(args)
    Some("bridge-dispatch") => render_runtime_bridge_dispatch(args)
    Some("bridge-loop") => render_runtime_bridge_loop(args)
    Some("invoke") => render_runtime_invoke(args)
    Some("--manifest") | None => render_runtime_manifest(args)
    Some(command) =>
      runtime_fail("unknown runtime command: \{command}\n\n" + runtime_help())
  }
}

///|
async fn render_runtime_manifest(args : Array[String]) -> RuntimeCliResult {
  match runtime_manifest_arg(args) {
    Ok(path) => {
      let text = @fs.read_file(path).text() catch {
        error =>
          return runtime_fail(
            "Lepusa runtime\n[fail] could not read manifest \{path}: \{error}\n",
          )
      }
      render_runtime_manifest_text(path, text)
    }
    Err(problem) => runtime_fail(problem + "\n")
  }
}

///|
async fn render_runtime_asset(args : Array[String]) -> RuntimeCliResult {
  let url = args.get(1).unwrap_or("")
  if url == "" || url == "--manifest" {
    return runtime_fail("asset url is required\n")
  }
  match runtime_manifest_path(args) {
    Ok(path) => {
      let text = @fs.read_file(path).text() catch {
        error =>
          return runtime_fail(
            "Lepusa runtime asset\n[fail] could not read manifest \{path}: \{error}\n",
          )
      }
      render_runtime_asset_text(path, text, url)
    }
    Err(problem) => runtime_fail(problem + "\n")
  }
}

///|
fn render_runtime_manifest_text(
  path : String,
  text : String,
) -> RuntimeCliResult {
  match @bundled.BundledRuntimeManifest::parse(path, text) {
    Ok(manifest) => runtime_ok(manifest.summary())
    Err(problem) => runtime_fail("Lepusa runtime\n[fail] \{problem}\n")
  }
}

///|
async fn render_runtime_run(
  args : Array[String],
  launch~ : Bool,
) -> RuntimeCliResult {
  match runtime_manifest_path(args) {
    Ok(path) => {
      let text = @fs.read_file(path).text() catch {
        error =>
          return runtime_fail(
            "Lepusa runtime run\n[fail] could not read manifest \{path}: \{error}\n",
          )
      }
      render_runtime_run_text(path, text, launch~)
    }
    Err(problem) => runtime_fail(problem + "\n")
  }
}

///|
fn render_runtime_run_text(
  path : String,
  text : String,
  launch? : Bool = false,
) -> RuntimeCliResult {
  match @bundled.BundledRuntimeManifest::parse(path, text) {
    Err(problem) => runtime_fail("Lepusa runtime run\n[fail] \{problem}\n")
    Ok(manifest) =>
      match manifest.target() {
        "macos" => render_macos_runtime_run(manifest, launch~)
        "linux" => render_linux_runtime_run(manifest, launch~)
        "windows" => render_windows_runtime_run(manifest, launch~)
        _ => render_portable_runtime_run(manifest, launch~)
      }
  }
}

///|
fn render_macos_runtime_run(
  manifest : @bundled.BundledRuntimeManifest,
  launch~ : Bool,
) -> RuntimeCliResult {
  let services = runtime_service_summary(manifest)
  let result = if launch {
    @macos.launch_bundled(manifest)
  } else {
    @macos.run_bundled(manifest)
  }
  match result {
    Err(problems) =>
      runtime_fail(render_runtime_run_problems("Lepusa runtime run", problems))
    Ok(result) =>
      runtime_ok(
        render_runtime_run_report(
          macos_runtime_run_report(result, services),
          launch~,
          include_title=true,
          include_load_url=true,
          include_bridge_url=true,
          include_bridge_routes=true,
        ),
      )
  }
}

///|
fn render_linux_runtime_run(
  manifest : @bundled.BundledRuntimeManifest,
  launch~ : Bool,
) -> RuntimeCliResult {
  let result = if launch {
    @linux.launch_bundled(manifest)
  } else {
    @linux.run_bundled(manifest)
  }
  match result {
    Err(problems) =>
      runtime_fail(render_runtime_run_problems("Lepusa runtime run", problems))
    Ok(result) =>
      runtime_ok(render_bundled_runtime_run_report(result.report(), launch~))
  }
}

///|
fn render_windows_runtime_run(
  manifest : @bundled.BundledRuntimeManifest,
  launch~ : Bool,
) -> RuntimeCliResult {
  let result = if launch {
    @windows.launch_bundled(manifest)
  } else {
    @windows.run_bundled(manifest)
  }
  match result {
    Err(problems) =>
      runtime_fail(render_runtime_run_problems("Lepusa runtime run", problems))
    Ok(result) =>
      runtime_ok(render_bundled_runtime_run_report(result.report(), launch~))
  }
}

///|
fn render_portable_runtime_run(
  manifest : @bundled.BundledRuntimeManifest,
  launch~ : Bool,
) -> RuntimeCliResult {
  let mode : @bundled.BundledRunMode = if launch {
    BundledOpenWindow
  } else {
    BundledDryRun
  }
  match manifest.run(mode~) {
    Ok(result) =>
      runtime_ok(render_bundled_runtime_run_report(result.report(), launch~))
    Err(problem) => runtime_fail("Lepusa runtime run\n[fail] \{problem}\n")
  }
}

///|
fn macos_runtime_run_report(
  result : @macos.MacOSRunResult,
  services : @bundled.BundledServicePlan,
) -> @lepusa.RunReport {
  let plan = result.plan()
  let first_webview = plan.first_webview()
  let first_window_title = match first_webview {
    Ok(webview) => webview.title()
    Err(_) => ""
  }
  let first_window_url = match first_webview {
    Ok(webview) => webview.url()
    Err(_) => ""
  }
  let load_url = match first_webview {
    Ok(webview) => webview.load_url()
    Err(_) => ""
  }
  @lepusa.RunReport::new(
    target="macos",
    backend="macos",
    engine="WKWebView",
    status=result.status(),
    webviews=plan.webviews().length(),
    first_window_title~,
    first_window_url~,
    load_url~,
    local_services=services.services().length(),
    service_supervisor=services.requires_supervisor(),
    service_start_order=services.startup_service_names(),
    startup_operations=plan.execution().startup_operations().length(),
    lifecycle_steps=plan.execution().lifecycle_steps().length(),
    bridge_sync_routes=plan.bridge().sync_command_routes().length(),
    bridge_async_routes=plan.bridge().async_command_routes().length(),
  )
}

///|
fn render_bundled_runtime_run_report(
  report : @lepusa.RunReport,
  launch~ : Bool,
) -> String {
  render_runtime_run_report(
    report,
    launch~,
    include_title=true,
    include_load_url=true,
    include_bridge_url=true,
    include_bridge_routes=true,
  )
}

///|
fn render_runtime_run_report(
  report : @lepusa.RunReport,
  launch~ : Bool,
  include_title? : Bool = false,
  include_load_url? : Bool = false,
  include_bridge_url? : Bool = false,
  include_bridge_routes? : Bool = false,
) -> String {
  let title = if include_title {
    "title: \{report.first_window_title()}\n"
  } else {
    ""
  }
  let load_url = if include_load_url {
    "load-url: \{report.load_url()}\n"
  } else {
    ""
  }
  let bridge_url = if include_bridge_url {
    "bridge: \{report.bridge_url()}\n"
  } else {
    ""
  }
  let bridge_routes = if include_bridge_routes {
    "bridge-sync-routes: \{report.bridge_sync_routes()}\n" +
    "bridge-async-routes: \{report.bridge_async_routes()}\n"
  } else {
    ""
  }
  [
    "Lepusa runtime run",
    "mode: \{if launch { "launch" } else { "dry-run" }}",
    "target: \{report.target()}",
    "backend: \{report.backend()}",
    "engine: \{report.engine()}",
    "status: \{report.status().name()}",
    "webviews: \{report.webviews()}",
    title + "first-window-url: \{report.first_window_url()}",
    load_url + bridge_url + "local-services: \{report.local_services()}",
    "service-supervisor: \{report.service_supervisor()}",
    "service-start-order: \{report.service_start_order().join(",")}",
    "startup-operations: \{report.startup_operations()}",
    "lifecycle-steps: \{report.lifecycle_steps()}",
    bridge_routes,
    "",
  ].join("\n")
}

///|
fn runtime_service_summary(
  manifest : @bundled.BundledRuntimeManifest,
) -> @bundled.BundledServicePlan {
  match manifest.service_plan() {
    Ok(plan) => plan
    Err(_) => @bundled.BundledServicePlan::new(services=[])
  }
}

///|
fn render_runtime_run_problems(
  title : String,
  problems : Array[String],
) -> String {
  let lines : Array[String] = [title]
  for problem in problems {
    lines.push("[fail] \{problem}")
  }
  lines.push("")
  lines.join("\n")
}

///|
fn runtime_manifest_arg(args : Array[String]) -> Result[String, String] {
  match args.get(0) {
    None => Ok("lepusa/runtime.json")
    Some("--manifest") =>
      match args.get(1) {
        Some(path) if path != "" => Ok(path)
        _ => Err("--manifest requires a file path")
      }
    Some(value) => Err("unknown runtime command: \{value}")
  }
}

///|
fn runtime_manifest_path(args : Array[String]) -> Result[String, String] {
  for i in 0..<args.length() {
    if args[i] == "--manifest" {
      match args.get(i + 1) {
        Some(path) if path != "" => return Ok(path)
        _ => return Err("--manifest requires a file path")
      }
    }
  }
  Ok("lepusa/runtime.json")
}

///|
fn runtime_has_flag(args : Array[String], flag : String) -> Bool {
  for arg in args {
    if arg == flag {
      return true
    }
  }
  false
}

///|
fn runtime_bridge_mode_from_args(
  args : Array[String],
) -> @runtime_core.NativeBridgeSchedulerMode {
  if runtime_has_flag(args, "--async-bridge") {
    NativeBridgeAsyncCapable
  } else {
    NativeBridgeSyncOnly
  }
}

///|
fn runtime_ok(output : String) -> RuntimeCliResult {
  { exit_code: 0, output }
}

///|
fn runtime_fail(output : String) -> RuntimeCliResult {
  { exit_code: 1, output }
}

///|
fn runtime_help() -> String {
  (
    #|lepusa-runtime: bundled Lepusa runtime launcher
    #|
    #|Usage:
    #|  lepusa-runtime --manifest <lepusa/runtime.json>
    #|  lepusa-runtime run --manifest <lepusa/runtime.json>
    #|  lepusa-runtime launch --manifest <lepusa/runtime.json>
    #|  lepusa-runtime bootstrap --manifest <lepusa/runtime.json>
    #|  lepusa-runtime launch-session [--async-bridge] --manifest <lepusa/runtime.json>
    #|  lepusa-runtime asset <url> --manifest <lepusa/runtime.json>
    #|  lepusa-runtime lifecycle <event> [window] --manifest <lepusa/runtime.json>
    #|  lepusa-runtime bridge-task <window> <plugin.command> [payload] --manifest <lepusa/runtime.json>
    #|  lepusa-runtime bridge-handoff <window> <plugin.command> [payload] --manifest <lepusa/runtime.json>
    #|  lepusa-runtime bridge-complete <window> <plugin.command> [payload] --manifest <lepusa/runtime.json>
    #|  lepusa-runtime bridge-dispatch <window> <plugin.command> [payload] --manifest <lepusa/runtime.json>
    #|  lepusa-runtime bridge-loop <window> <plugin.command> [payload] --manifest <lepusa/runtime.json>
    #|  lepusa-runtime invoke <window> <plugin.command> [payload] --manifest <lepusa/runtime.json>
    #|
  )
}

///|
async fn render_runtime_bridge_task(args : Array[String]) -> RuntimeCliResult {
  let values = runtime_positional_args(args)
  let window_label = values.get(1).unwrap_or("")
  let route = values.get(2).unwrap_or("")
  let payload = values.get(3).unwrap_or("")
  if window_label == "" {
    return runtime_fail("bridge-task window is required\n")
  }
  if route == "" || route == "--manifest" {
    return runtime_fail("bridge-task route is required\n")
  }
  match runtime_parse_invoke_route(route, command_name="bridge-task") {
    Err(problem) => return runtime_fail(problem + "\n")
    Ok(_) => ()
  }
  match runtime_manifest_path(args) {
    Ok(path) => {
      let text = @fs.read_file(path).text() catch {
        error =>
          return runtime_fail(
            "Lepusa runtime bridge-task\n[fail] could not read manifest \{path}: \{error}\n",
          )
      }
      render_runtime_bridge_task_text(path, text, window_label, route, payload)
    }
    Err(problem) => runtime_fail(problem + "\n")
  }
}

///|
fn render_runtime_bridge_task_text(
  path : String,
  text : String,
  window_label : String,
  route : String,
  payload : String,
) -> RuntimeCliResult {
  match runtime_parse_invoke_route(route, command_name="bridge-task") {
    Err(problem) => runtime_fail(problem + "\n")
    Ok((plugin, command)) =>
      match @bundled.BundledRuntimeManifest::parse(path, text) {
        Err(problem) =>
          runtime_fail("Lepusa runtime bridge-task\n[fail] \{problem}\n")
        Ok(manifest) => {
          let request = @lepusa.InvokeRequest::new(
            id="cli",
            window_label~,
            plugin~,
            command~,
            payload~,
          )
          let message = @runtime_core.encode_invoke_request_json(request)
          match manifest.bridge_dispatch_task(message) {
            Ok(task) => runtime_ok(task.to_json() + "\n")
            Err(problems) =>
              runtime_fail(
                render_runtime_run_problems(
                  "Lepusa runtime bridge-task", problems,
                ),
              )
          }
        }
      }
  }
}

///|
async fn render_runtime_bridge_handoff(
  args : Array[String],
) -> RuntimeCliResult {
  let values = runtime_positional_args(args)
  let window_label = values.get(1).unwrap_or("")
  let route = values.get(2).unwrap_or("")
  let payload = values.get(3).unwrap_or("")
  if window_label == "" {
    return runtime_fail("bridge-handoff window is required\n")
  }
  if route == "" || route == "--manifest" {
    return runtime_fail("bridge-handoff route is required\n")
  }
  match runtime_parse_invoke_route(route, command_name="bridge-handoff") {
    Err(problem) => return runtime_fail(problem + "\n")
    Ok(_) => ()
  }
  match runtime_manifest_path(args) {
    Ok(path) => {
      let text = @fs.read_file(path).text() catch {
        error =>
          return runtime_fail(
            "Lepusa runtime bridge-handoff\n[fail] could not read manifest \{path}: \{error}\n",
          )
      }
      render_runtime_bridge_handoff_text(
        path, text, window_label, route, payload,
      )
    }
    Err(problem) => runtime_fail(problem + "\n")
  }
}

///|
fn render_runtime_bridge_handoff_text(
  path : String,
  text : String,
  window_label : String,
  route : String,
  payload : String,
) -> RuntimeCliResult {
  match runtime_parse_invoke_route(route, command_name="bridge-handoff") {
    Err(problem) => runtime_fail(problem + "\n")
    Ok((plugin, command)) =>
      match @bundled.BundledRuntimeManifest::parse(path, text) {
        Err(problem) =>
          runtime_fail("Lepusa runtime bridge-handoff\n[fail] \{problem}\n")
        Ok(manifest) => {
          let runtime = @bundled.BundledRuntime::new(manifest)
          let request = @lepusa.InvokeRequest::new(
            id="cli",
            window_label~,
            plugin~,
            command~,
            payload~,
          )
          let message = @runtime_core.encode_invoke_request_json(request)
          match runtime.bridge_handoff(message, window_label~) {
            Ok(handoff) => runtime_ok(handoff.to_json() + "\n")
            Err(problems) =>
              runtime_fail(
                render_runtime_run_problems(
                  "Lepusa runtime bridge-handoff", problems,
                ),
              )
          }
        }
      }
  }
}

///|
async fn render_runtime_bridge_complete(
  args : Array[String],
) -> RuntimeCliResult {
  let values = runtime_positional_args(args)
  let window_label = values.get(1).unwrap_or("")
  let route = values.get(2).unwrap_or("")
  let payload = values.get(3).unwrap_or("")
  if window_label == "" {
    return runtime_fail("bridge-complete window is required\n")
  }
  if route == "" || route == "--manifest" {
    return runtime_fail("bridge-complete route is required\n")
  }
  match runtime_parse_invoke_route(route, command_name="bridge-complete") {
    Err(problem) => return runtime_fail(problem + "\n")
    Ok(_) => ()
  }
  match runtime_manifest_path(args) {
    Ok(path) => {
      let text = @fs.read_file(path).text() catch {
        error =>
          return runtime_fail(
            "Lepusa runtime bridge-complete\n[fail] could not read manifest \{path}: \{error}\n",
          )
      }
      render_runtime_bridge_complete_text(
        path, text, window_label, route, payload,
      )
    }
    Err(problem) => runtime_fail(problem + "\n")
  }
}

///|
async fn render_runtime_bridge_complete_text(
  path : String,
  text : String,
  window_label : String,
  route : String,
  payload : String,
) -> RuntimeCliResult {
  match runtime_parse_invoke_route(route, command_name="bridge-complete") {
    Err(problem) => runtime_fail(problem + "\n")
    Ok((plugin, command)) =>
      match @bundled.BundledRuntimeManifest::parse(path, text) {
        Err(problem) =>
          runtime_fail("Lepusa runtime bridge-complete\n[fail] \{problem}\n")
        Ok(manifest) => {
          let runtime = @bundled.BundledRuntime::new(manifest)
          let request = @lepusa.InvokeRequest::new(
            id="cli",
            window_label~,
            plugin~,
            command~,
            payload~,
          )
          let message = @runtime_core.encode_invoke_request_json(request)
          match runtime.bridge_handoff(message, window_label~) {
            Ok(handoff) =>
              match handoff.complete_deferred(runtime) {
                Ok(completion) => runtime_ok(completion.to_json() + "\n")
                Err(problem) =>
                  runtime_fail(
                    "Lepusa runtime bridge-complete\n[fail] \{problem}\n",
                  )
              }
            Err(problems) =>
              runtime_fail(
                render_runtime_run_problems(
                  "Lepusa runtime bridge-complete", problems,
                ),
              )
          }
        }
      }
  }
}

///|
async fn render_runtime_bridge_dispatch(
  args : Array[String],
) -> RuntimeCliResult {
  let values = runtime_positional_args(args)
  let window_label = values.get(1).unwrap_or("")
  let route = values.get(2).unwrap_or("")
  let payload = values.get(3).unwrap_or("")
  if window_label == "" {
    return runtime_fail("bridge-dispatch window is required\n")
  }
  if route == "" || route == "--manifest" {
    return runtime_fail("bridge-dispatch route is required\n")
  }
  match runtime_parse_invoke_route(route, command_name="bridge-dispatch") {
    Err(problem) => return runtime_fail(problem + "\n")
    Ok(_) => ()
  }
  match runtime_manifest_path(args) {
    Ok(path) => {
      let text = @fs.read_file(path).text() catch {
        error =>
          return runtime_fail(
            "Lepusa runtime bridge-dispatch\n[fail] could not read manifest \{path}: \{error}\n",
          )
      }
      render_runtime_bridge_dispatch_text(
        path, text, window_label, route, payload,
      )
    }
    Err(problem) => runtime_fail(problem + "\n")
  }
}

///|
async fn render_runtime_bridge_dispatch_text(
  path : String,
  text : String,
  window_label : String,
  route : String,
  payload : String,
) -> RuntimeCliResult {
  match runtime_parse_invoke_route(route, command_name="bridge-dispatch") {
    Err(problem) => runtime_fail(problem + "\n")
    Ok((plugin, command)) =>
      match @bundled.BundledRuntimeManifest::parse(path, text) {
        Err(problem) =>
          runtime_fail("Lepusa runtime bridge-dispatch\n[fail] \{problem}\n")
        Ok(manifest) => {
          let runtime = @bundled.BundledRuntime::new(manifest)
          let request = @lepusa.InvokeRequest::new(
            id="cli",
            window_label~,
            plugin~,
            command~,
            payload~,
          )
          let message = @runtime_core.encode_invoke_request_json(request)
          match runtime.dispatch_bridge_message(message, window_label~) {
            Ok(dispatch) => runtime_ok(dispatch.to_json() + "\n")
            Err(problems) =>
              runtime_fail(
                render_runtime_run_problems(
                  "Lepusa runtime bridge-dispatch", problems,
                ),
              )
          }
        }
      }
  }
}

///|
async fn render_runtime_bridge_loop(args : Array[String]) -> RuntimeCliResult {
  let values = runtime_positional_args(args)
  let window_label = values.get(1).unwrap_or("")
  let route = values.get(2).unwrap_or("")
  let payload = values.get(3).unwrap_or("")
  if window_label == "" {
    return runtime_fail("bridge-loop window is required\n")
  }
  if route == "" || route == "--manifest" {
    return runtime_fail("bridge-loop route is required\n")
  }
  match runtime_parse_invoke_route(route, command_name="bridge-loop") {
    Err(problem) => return runtime_fail(problem + "\n")
    Ok(_) => ()
  }
  match runtime_manifest_path(args) {
    Ok(path) => {
      let text = @fs.read_file(path).text() catch {
        error =>
          return runtime_fail(
            "Lepusa runtime bridge-loop\n[fail] could not read manifest \{path}: \{error}\n",
          )
      }
      render_runtime_bridge_loop_text(path, text, window_label, route, payload)
    }
    Err(problem) => runtime_fail(problem + "\n")
  }
}

///|
async fn render_runtime_bridge_loop_text(
  path : String,
  text : String,
  window_label : String,
  route : String,
  payload : String,
) -> RuntimeCliResult {
  match runtime_parse_invoke_route(route, command_name="bridge-loop") {
    Err(problem) => runtime_fail(problem + "\n")
    Ok((plugin, command)) =>
      match @bundled.BundledRuntimeManifest::parse(path, text) {
        Err(problem) =>
          runtime_fail("Lepusa runtime bridge-loop\n[fail] \{problem}\n")
        Ok(manifest) => {
          let request = @lepusa.InvokeRequest::new(
            id="cli",
            window_label~,
            plugin~,
            command~,
            payload~,
          )
          let message = @runtime_core.encode_invoke_request_json(request)
          let result = manifest
            .bridge_loop_adapter()
            .receive_message(@utf8.encode(message))
          let evaluation_plan = result.evaluation_plan(window_label~)
          runtime_ok(
            [
              "{",
              "\"result\":\{result.to_json()},",
              "\"evaluationPlan\":\{evaluation_plan.to_json()}",
              "}\n",
            ].join(""),
          )
        }
      }
  }
}

///|
async fn render_runtime_invoke(args : Array[String]) -> RuntimeCliResult {
  let values = runtime_positional_args(args)
  let window_label = values.get(1).unwrap_or("")
  let route = values.get(2).unwrap_or("")
  let payload = values.get(3).unwrap_or("")
  if window_label == "" {
    return runtime_fail("invoke window is required\n")
  }
  if route == "" || route == "--manifest" {
    return runtime_fail("invoke route is required\n")
  }
  match runtime_parse_invoke_route(route, command_name="invoke") {
    Err(problem) => return runtime_fail(problem + "\n")
    Ok(_) => ()
  }
  match runtime_manifest_path(args) {
    Ok(path) => {
      let text = @fs.read_file(path).text() catch {
        error =>
          return runtime_fail(
            "Lepusa runtime invoke\n[fail] could not read manifest \{path}: \{error}\n",
          )
      }
      render_runtime_invoke_text(path, text, window_label, route, payload)
    }
    Err(problem) => runtime_fail(problem + "\n")
  }
}

///|
fn runtime_positional_args(args : Array[String]) -> Array[String] {
  let values : Array[String] = []
  let mut skip_next = false
  for arg in args {
    if skip_next {
      skip_next = false
    } else if arg == "--manifest" {
      skip_next = true
    } else {
      values.push(arg)
    }
  }
  values
}

///|
async fn render_runtime_invoke_text(
  path : String,
  text : String,
  window_label : String,
  route : String,
  payload : String,
) -> RuntimeCliResult {
  match runtime_parse_invoke_route(route, command_name="invoke") {
    Err(problem) => runtime_fail(problem + "\n")
    Ok(_) =>
      match @bundled.BundledRuntimeManifest::parse(path, text) {
        Ok(manifest) =>
          runtime_ok(
            manifest.dispatch_json_async(
              id="cli",
              window_label~,
              route~,
              payload~,
            ) +
            "\n",
          )
        Err(problem) =>
          runtime_fail("Lepusa runtime invoke\n[fail] \{problem}\n")
      }
  }
}

///|
fn runtime_parse_invoke_route(
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
