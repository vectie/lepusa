///|
struct CliResult {
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
fn Array::with_first(self : Array[String], value : String) -> Array[String] {
  let args : Array[String] = [value]
  for i in 1..<self.length() {
    args.push(self[i])
  }
  args
}

///|
fn project_path_arg(args : Array[String]) -> String? {
  for i in 0..<args.length() {
    if args[i] == "--project" {
      return args.get(i + 1)
    }
  }
  None
}

///|
fn project_flag_missing_value(args : Array[String]) -> Bool {
  for i in 0..<args.length() {
    if args[i] == "--project" && args.get(i + 1) is None {
      return true
    }
  }
  false
}

///|
async fn project_config_path(args : Array[String]) -> String? {
  match project_path_arg(args) {
    Some(path) => Some(path)
    None => {
      let found = @fs.exists("lepusa.json") catch { _ => false }
      if found {
        Some("lepusa.json")
      } else {
        None
      }
    }
  }
}

///|
fn positional_args(args : Array[String]) -> Array[String] {
  let values : Array[String] = []
  let mut skip_next = false
  for i in 1..<args.length() {
    if skip_next {
      skip_next = false
    } else if args[i] == "--project" {
      skip_next = true
    } else {
      values.push(args[i])
    }
  }
  values
}

///|
fn has_flag(args : Array[String], flag : String) -> Bool {
  for arg in args {
    if arg == flag {
      return true
    }
  }
  false
}

///|
fn render_cli(args : Array[String]) -> CliResult {
  match args.get(0) {
    None => ok(help_text())
    Some("help") | Some("--help") | Some("-h") => ok(help_text())
    Some("doctor") => render_doctor(args)
    Some("plan") => render_plan()
    Some("manifest") => render_manifest()
    Some("native-plan") => render_native_plan(args)
    Some("run") => render_run(args)
    Some("bridge") => render_bridge()
    Some("bundle-plan") => render_bundle_plan(args)
    Some("dev") => fail("dev requires the native async runner\n")
    Some("init") => fail("init requires the native async runner\n")
    Some("plugin") => fail("plugin commands require the native async runner\n")
    Some("invoke") => fail("invoke requires the native async runner\n")
    Some("asset") => fail("asset requires the native async runner\n")
    Some("lifecycle") => fail("lifecycle requires the native async runner\n")
    Some("bundle-write") =>
      fail("bundle-write requires the native async runner\n")
    Some(command) => fail("unknown command: \{command}\n\n" + help_text())
  }
}

///|
async fn render_cli_async(args : Array[String]) -> CliResult {
  match args.get(0) {
    Some("doctor") => render_doctor_async(args)
    Some("plan") => render_plan_async(args)
    Some("manifest") => render_manifest_async(args)
    Some("native-plan") => render_native_plan_async(args)
    Some("run") => render_run_async(args)
    Some("bridge") => render_bridge_async(args)
    Some("dev") => render_dev_async(args)
    Some("init") => render_init(args)
    Some("plugin") => render_plugin(args)
    Some("invoke") => render_invoke_async(args)
    Some("asset") => render_asset_async(args)
    Some("lifecycle") => render_lifecycle_async(args)
    Some("bundle-plan") => render_bundle_plan_async(args)
    Some("bundle-write") => render_bundle_write(args)
    Some("bundle") => render_bundle_write(args.with_first("bundle-write"))
    Some("build") => render_bundle_write(args.with_first("bundle-write"))
    _ => render_cli(args)
  }
}

///|
fn ok(output : String) -> CliResult {
  { exit_code: 0, output }
}

///|
fn fail(output : String) -> CliResult {
  { exit_code: 1, output }
}

///|
fn help_text() -> String {
  (
    #|lepusa: MoonBit-native desktop framework
    #|
    #|Usage:
    #|  lepusa doctor [macos|windows|linux]
    #|  lepusa plan
    #|  lepusa manifest
    #|  lepusa native-plan [macos|windows|linux]
    #|  lepusa run [macos|windows|linux] [--launch]
    #|  lepusa bridge
    #|  lepusa dev
    #|  lepusa invoke <window> <plugin.command> [payload]
    #|  lepusa asset <url>
    #|  lepusa lifecycle <event> [window]
    #|  lepusa init [out-dir]
    #|  lepusa plugin new <name> [out-dir]
    #|  lepusa bundle-plan [macos|windows|linux]
    #|  lepusa bundle-write [macos|windows|linux] [out-dir]
    #|  lepusa build [macos|windows|linux] [out-dir]
    #|  lepusa bundle [macos|windows|linux] [out-dir]
    #|
    #|Options:
    #|  --project <lepusa.json>
    #|
  )
}

///|
async fn project_runtime_plan(
  args : Array[String],
) -> Result[@lepusa.RuntimePlan, Array[String]] {
  if project_flag_missing_value(args) {
    return Err(["--project requires a file path"])
  }
  match project_config_path(args) {
    Some(path) =>
      match load_project_config(path) {
        Ok(project) => project.manifest().runtime_plan(project.root())
        Err(problems) => Err(problems)
      }
    None => sample_runtime_plan()
  }
}

///|
async fn project_runtime_host(
  args : Array[String],
) -> Result[@runtime.RuntimeHost, Array[String]] {
  if project_flag_missing_value(args) {
    return Err(["--project requires a file path"])
  }
  match project_config_path(args) {
    Some(path) =>
      match load_project_config(path) {
        Ok(project) =>
          match project.manifest().runtime_plan(project.root()) {
            Ok(plan) =>
              Ok(@runtime.RuntimeHost::new(plan, registry=project.registry()))
            Err(problems) => Err(problems)
          }
        Err(problems) => Err(problems)
      }
    None =>
      match sample_runtime_plan() {
        Ok(plan) => Ok(@runtime.RuntimeHost::new(plan))
        Err(problems) => Err(problems)
      }
  }
}

///|
async fn project_bundle_plan(
  args : Array[String],
  target : @lepusa.BundleTarget,
) -> Result[@lepusa.BundlePlan, Array[String]] {
  if project_flag_missing_value(args) {
    return Err(["--project requires a file path"])
  }
  match project_config_path(args) {
    Some(path) =>
      match load_project_config(path) {
        Ok(project) =>
          project
          .manifest()
          .bundle_plan(
            project.root(),
            target~,
            registered_routes=project.registry().routes(),
          )
        Err(problems) => Err(problems)
      }
    None => sample_manifest().bundle_plan(sample_root(), target~)
  }
}

///|
async fn render_plugin(args : Array[String]) -> CliResult {
  match args.get(1) {
    Some("new") => render_plugin_new(args)
    Some(command) =>
      fail("unknown plugin command: \{command}\n\n" + help_text())
    None => fail("plugin command is required\n\n" + help_text())
  }
}

///|
async fn render_plugin_new(args : Array[String]) -> CliResult {
  let name = args.get(2).unwrap_or("")
  let out_dir = args.get(3).unwrap_or("")
  match @scaffold.write_plugin(name, out_dir) {
    Ok(result) =>
      ok(
        "Lepusa plugin new\n" +
        "plugin: \{result.plugin_name()}\n" +
        "root: \{result.root()}\n" +
        "files: \{result.files().length()}\n",
      )
    Err(problems) => fail(render_problems("Lepusa plugin new", problems))
  }
}

///|
async fn render_doctor_async(args : Array[String]) -> CliResult {
  let values = positional_args(args)
  match parse_bundle_target(values.get(0)) {
    Ok(target) =>
      match project_runtime_host(args) {
        Ok(host) =>
          match project_bundle_plan(args, target) {
            Ok(bundle) => render_doctor_host(host, bundle)
            Err(problems) => fail(render_problems("Lepusa doctor", problems))
          }
        Err(problems) => fail(render_problems("Lepusa doctor", problems))
      }
    Err(problem) => fail(problem + "\n")
  }
}

///|
async fn render_init(args : Array[String]) -> CliResult {
  let out_dir = args.get(1).unwrap_or("lepusa-app")
  match @scaffold.write_app(out_dir) {
    Ok(result) =>
      ok(
        "Lepusa init\n" +
        "root: \{result.root()}\n" +
        "files: \{result.files().length()}\n",
      )
    Err(problems) => fail(render_problems("Lepusa init", problems))
  }
}

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
async fn render_native_plan_async(args : Array[String]) -> CliResult {
  let values = positional_args(args)
  match parse_bundle_target(values.get(0)) {
    Ok(target) =>
      match project_runtime_host(args) {
        Ok(host) =>
          match native_runtime_for_target(target, host) {
            Ok(runtime) => render_native_runner_plan(runtime)
            Err(problems) =>
              fail(render_problems("Lepusa native plan", problems))
          }
        Err(problems) => fail(render_problems("Lepusa native plan", problems))
      }
    Err(problem) => fail(problem + "\n")
  }
}

///|
async fn render_run_async(args : Array[String]) -> CliResult {
  let values = positional_args(args)
  match parse_bundle_target(values.get(0)) {
    Ok(target) =>
      match project_runtime_host(args) {
        Ok(host) =>
          match native_runtime_for_target(target, host) {
            Ok(runtime) =>
              if has_flag(args, "--launch") {
                render_native_launch(target, runtime)
              } else {
                render_native_run_summary(target, runtime)
              }
            Err(problems) => fail(render_problems("Lepusa run", problems))
          }
        Err(problems) => fail(render_problems("Lepusa run", problems))
      }
    Err(problem) => fail(problem + "\n")
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
    return Err("invoke route must be <plugin.command>")
  }
  Ok((plugin, command))
}

///|
fn render_doctor(args : Array[String]) -> CliResult {
  let values = positional_args(args)
  match parse_bundle_target(values.get(0)) {
    Ok(target) =>
      match sample_runtime_plan() {
        Ok(plan) =>
          match sample_manifest().bundle_plan(sample_root(), target~) {
            Ok(bundle) =>
              render_doctor_host(@runtime.RuntimeHost::new(plan), bundle)
            Err(problems) => fail(render_problems("Lepusa doctor", problems))
          }
        Err(problems) => fail(render_problems("Lepusa doctor", problems))
      }
    Err(problem) => fail(problem + "\n")
  }
}

///|
fn render_doctor_host(
  host : @runtime.RuntimeHost,
  bundle : @lepusa.BundlePlan,
) -> CliResult {
  let plan = host.plan()
  match host.launch_manifest() {
    Ok(manifest) =>
      match bundle.files() {
        Ok(files) =>
          ok(
            "Lepusa doctor\n" +
            "[ok] public-api: root package can build launch/runtime plans\n" +
            "[ok] runtime: backend=\{plan.backend().name()} protocol=\{plan.asset_protocol()}\n" +
            "[ok] manifest: webviews=\{manifest.webviews().length()} routes=\{manifest.command_routes().length()}\n" +
            "[ok] ipc: routes=\{plan.command_routes().length()}\n" +
            "[ok] bundle: target=\{bundle.target().name()} files=\{files.length()} resources=\{bundle.resources().length()}\n" +
            "[ok] signing: prerequisites=\{bundle.signing_prerequisites().length()}\n" +
            render_signing_prerequisites(bundle) +
            render_native_backend_diagnostics(),
          )
        Err(problems) => fail(render_problems("Lepusa doctor", problems))
      }
    Err(problems) => fail(render_problems("Lepusa doctor", problems))
  }
}

///|
fn render_signing_prerequisites(bundle : @lepusa.BundlePlan) -> String {
  let lines : Array[String] = []
  for item in bundle.signing_prerequisites() {
    lines.push("[info] signing: \{item.kind().name()} \{item.name()}\n")
  }
  lines.join("")
}

///|
fn render_native_backend_diagnostics() -> String {
  [
    render_native_backend_line("macos", @macos_backend.detect()),
    render_native_backend_line("windows", @windows_backend.detect()),
    render_native_backend_line("linux", @linux_backend.detect()),
  ].join("")
}

///|
fn render_native_backend_line(
  platform : String,
  backend : Result[@runtime.NativeBackend, String],
) -> String {
  match backend {
    Ok(backend) =>
      "[ok] platform: \{platform} engine=\{backend.webview_engine()}\n"
    Err(problem) => "[warn] platform: \{platform} \{problem}\n"
  }
}

///|
fn render_manifest() -> CliResult {
  match sample_runtime_plan() {
    Ok(plan) =>
      match plan.launch_manifest() {
        Ok(manifest) => ok(manifest.to_json() + "\n")
        Err(problems) => fail(render_problems("Lepusa manifest", problems))
      }
    Err(problems) => fail(render_problems("Lepusa manifest", problems))
  }
}

///|
fn render_native_plan(args : Array[String]) -> CliResult {
  match parse_bundle_target(args.get(1)) {
    Ok(target) =>
      match sample_runtime_plan() {
        Ok(plan) =>
          match
            native_runtime_for_target(target, @runtime.RuntimeHost::new(plan)) {
            Ok(runtime) => render_native_runner_plan(runtime)
            Err(problems) =>
              fail(render_problems("Lepusa native plan", problems))
          }
        Err(problems) => fail(render_problems("Lepusa native plan", problems))
      }
    Err(problem) => fail(problem + "\n")
  }
}

///|
fn render_run(args : Array[String]) -> CliResult {
  let values = positional_args(args)
  match parse_bundle_target(values.get(0)) {
    Ok(target) =>
      match sample_runtime_plan() {
        Ok(plan) =>
          match
            native_runtime_for_target(target, @runtime.RuntimeHost::new(plan)) {
            Ok(runtime) =>
              if has_flag(args, "--launch") {
                render_native_launch(target, runtime)
              } else {
                render_native_run_summary(target, runtime)
              }
            Err(problems) => fail(render_problems("Lepusa run", problems))
          }
        Err(problems) => fail(render_problems("Lepusa run", problems))
      }
    Err(problem) => fail(problem + "\n")
  }
}

///|
fn native_runtime_for_target(
  target : @lepusa.BundleTarget,
  host : @runtime.RuntimeHost,
) -> Result[@runtime.NativeRuntime, Array[String]] {
  match target {
    MacOS => @macos_backend.runtime(host)
    Windows => @windows_backend.runtime(host)
    Linux => @linux_backend.runtime(host)
  }
}

///|
fn render_native_launch(
  target : @lepusa.BundleTarget,
  runtime : @runtime.NativeRuntime,
) -> CliResult {
  match target {
    MacOS =>
      match @macos_backend.launch(runtime) {
        Ok(result) =>
          render_native_run_report(
            "Lepusa launch",
            macos_launch_report(target, runtime, result),
          )
        Err(problems) => fail(render_problems("Lepusa launch", problems))
      }
    Windows =>
      match @windows_backend.launch(runtime) {
        Ok(result) =>
          render_native_run_report(
            "Lepusa launch",
            runtime.run_report(target=target.name(), status=result.status()),
          )
        Err(problems) => fail(render_problems("Lepusa launch", problems))
      }
    Linux =>
      match @linux_backend.launch(runtime) {
        Ok(result) =>
          render_native_run_report(
            "Lepusa launch",
            runtime.run_report(target=target.name(), status=result.status()),
          )
        Err(problems) => fail(render_problems("Lepusa launch", problems))
      }
  }
}

///|
fn macos_launch_report(
  target : @lepusa.BundleTarget,
  runtime : @runtime.NativeRuntime,
  result : @macos_backend.MacOSRunResult,
) -> @lepusa.RunReport {
  let plan = result.plan()
  let load_url = match plan.first_webview() {
    Ok(webview) => webview.load_url()
    Err(_) => ""
  }
  runtime.run_report(
    target=target.name(),
    status=result.status(),
    load_url~,
    bridge_sync_routes=plan.bridge().sync_command_routes().length(),
    bridge_async_routes=plan.bridge().async_command_routes().length(),
  )
}

///|
fn render_native_run_report(
  title : String,
  report : @lepusa.RunReport,
  include_status? : Bool = true,
  include_bridge_url? : Bool = false,
  include_services? : Bool = false,
) -> CliResult {
  let status = if include_status {
    "status: \{report.status().name()}\n"
  } else {
    ""
  }
  let load_url = if report.load_url() == "" {
    ""
  } else {
    "load-url: \{report.load_url()}\n"
  }
  let bridge_url = if include_bridge_url {
    "bridge: \{report.bridge_url()}\n"
  } else {
    ""
  }
  let services = if include_services {
    "local-services: \{report.local_services()}\n" +
    "service-supervisor: \{report.service_supervisor()}\n" +
    "service-start-order: \{report.service_start_order().join(",")}\n"
  } else {
    ""
  }
  let bridge_routes = if report.bridge_sync_routes() == 0 &&
    report.bridge_async_routes() == 0 {
    ""
  } else {
    "bridge-sync-routes: \{report.bridge_sync_routes()}\n" +
    "bridge-async-routes: \{report.bridge_async_routes()}\n"
  }
  ok(
    title +
    "\n" +
    "target: \{report.target()}\n" +
    "backend: \{report.backend()}\n" +
    "engine: \{report.engine()}\n" +
    status +
    "webviews: \{report.webviews()}\n" +
    "first-window-url: \{report.first_window_url()}\n" +
    load_url +
    bridge_url +
    services +
    "startup-operations: \{report.startup_operations()}\n" +
    "lifecycle-steps: \{report.lifecycle_steps()}\n" +
    bridge_routes,
  )
}

///|
fn render_native_run_summary(
  target : @lepusa.BundleTarget,
  runtime : @runtime.NativeRuntime,
) -> CliResult {
  render_native_run_report(
    "Lepusa run",
    runtime.run_report(target=target.name(), status=RunPrepared),
    include_status=false,
    include_bridge_url=true,
    include_services=true,
  )
}

///|
fn render_native_runner_plan(runtime : @runtime.NativeRuntime) -> CliResult {
  ok(runtime.bootstrap_json() + "\n")
}

///|
fn render_plan() -> CliResult {
  match sample_runtime_plan() {
    Ok(plan) => render_runtime_plan(plan)
    Err(problems) => fail(render_problems("Lepusa runtime plan", problems))
  }
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

///|
fn render_bridge() -> CliResult {
  match sample_runtime_plan() {
    Ok(plan) =>
      match plan.bridge_script() {
        Ok(script) => ok(script.source())
        Err(problems) => fail(render_problems("Lepusa bridge", problems))
      }
    Err(problems) => fail(render_problems("Lepusa bridge", problems))
  }
}

///|
fn render_bundle_plan(args : Array[String]) -> CliResult {
  match parse_bundle_target(args.get(1)) {
    Ok(target) =>
      match sample_runtime_plan() {
        Ok(_) =>
          match sample_manifest().bundle_plan(sample_root(), target~) {
            Ok(plan) => render_bundle_plan_summary(plan)
            Err(problems) =>
              fail(render_problems("Lepusa bundle plan", problems))
          }
        Err(problems) => fail(render_problems("Lepusa bundle plan", problems))
      }
    Err(problem) => fail(problem + "\n")
  }
}

///|
async fn render_bundle_plan_async(args : Array[String]) -> CliResult {
  let values = positional_args(args)
  match parse_bundle_target(values.get(0)) {
    Ok(target) =>
      match project_bundle_plan(args, target) {
        Ok(plan) => render_bundle_plan_summary(plan)
        Err(problems) => fail(render_problems("Lepusa bundle plan", problems))
      }
    Err(problem) => fail(problem + "\n")
  }
}

///|
fn render_bundle_plan_summary(plan : @lepusa.BundlePlan) -> CliResult {
  match plan.files() {
    Ok(files) => {
      let local_service_count = match plan.runtime_manifest() {
        Ok(manifest) => manifest.local_services().length()
        Err(_) => 0
      }
      let filesystem_scope_count = match plan.runtime_manifest() {
        Ok(manifest) => manifest.file_system_scopes().length()
        Err(_) => 0
      }
      ok(
        "Lepusa bundle plan\n" +
        "target: \{plan.target().name()}\n" +
        "identifier: \{plan.identifier()}\n" +
        "executable: \{plan.executable_name()}\n" +
        "bundle: \{plan.bundle_name()}\n" +
        "local-services: \{local_service_count}\n" +
        "filesystem-scopes: \{filesystem_scope_count}\n" +
        "resources: \{plan.resources().length()}\n" +
        "signing-prerequisites: \{plan.signing_prerequisites().length()}\n" +
        "files: \{files.length()}\n",
      )
    }
    Err(problems) => fail(render_problems("Lepusa bundle files", problems))
  }
}

///|
async fn render_bundle_write(args : Array[String]) -> CliResult {
  let values = positional_args(args)
  match parse_bundle_target(values.get(0)) {
    Ok(target) => {
      let out_dir = values.get(1).unwrap_or("_build/lepusa-bundle")
      match project_bundle_plan(args, target) {
        Ok(plan) =>
          match @bundle.write_plan(plan, out_dir) {
            Ok(result) => {
              let local_service_count = match plan.runtime_manifest() {
                Ok(manifest) => manifest.local_services().length()
                Err(_) => 0
              }
              let filesystem_scope_count = match plan.runtime_manifest() {
                Ok(manifest) => manifest.file_system_scopes().length()
                Err(_) => 0
              }
              ok(
                "Lepusa bundle write\n" +
                "target: \{plan.target().name()}\n" +
                "root: \{result.root()}\n" +
                "local-services: \{local_service_count}\n" +
                "filesystem-scopes: \{filesystem_scope_count}\n" +
                "resources: \{plan.resources().length()}\n" +
                "resources-written: \{result.resources().length()}\n" +
                "verification-checks: \{result.checks().length()}\n" +
                "verified: \{result.verified().to_string()}\n" +
                "signing-prerequisites: \{plan.signing_prerequisites().length()}\n" +
                "files: \{result.files().length()}\n",
              )
            }
            Err(problems) =>
              fail(render_problems("Lepusa bundle write", problems))
          }
        Err(problems) => fail(render_problems("Lepusa bundle plan", problems))
      }
    }
    Err(problem) => fail(problem + "\n")
  }
}

///|
fn parse_bundle_target(
  target : String?,
) -> Result[@lepusa.BundleTarget, String] {
  let target = match target {
    None => @lepusa.MacOS
    Some("macos") => MacOS
    Some("windows") => Windows
    Some("linux") => Linux
    Some(value) => return Err("unknown bundle target: \{value}")
  }
  Ok(target)
}

///|
fn sample_runtime_plan() -> Result[@lepusa.RuntimePlan, Array[String]] {
  sample_manifest().runtime_plan(sample_root())
}

///|
fn sample_root() -> @lepusa.Cell {
  @lepusa.simple_cell(@lepusa.Html::text("<main></main>"))
}

///|
fn sample_manifest() -> @lepusa.ProjectManifest {
  @lepusa.ProjectManifest::new(
    sample_metadata(),
    runtime=@lepusa.RuntimeConfig::headless(),
  )
  .with_window(@lepusa.WindowConfig::new())
  .with_plugin(
    @lepusa.Plugin::new("core").command_sync("invoke").command_stream("events"),
  )
  .with_capability(
    @lepusa.Capability::new("core")
    .command("core.invoke")
    .command("core.events"),
  )
}

///|
fn sample_metadata() -> @lepusa.AppMetadata {
  @lepusa.AppMetadata::new(
    identifier="dev.vectie.lepusa.example",
    product_name="Lepusa Example",
    version="0.1.0",
  )
}

///|
fn render_problems(title : String, problems : Array[String]) -> String {
  let lines : Array[String] = [title]
  for problem in problems {
    lines.push("[fail] \{problem}")
  }
  lines.join("\n") + "\n"
}
