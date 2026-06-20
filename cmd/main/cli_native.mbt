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
async fn render_launch_session_async(args : Array[String]) -> CliResult {
  let values = positional_args(args)
  match parse_bundle_target(values.get(0)) {
    Ok(target) =>
      match project_runtime_host(args) {
        Ok(host) =>
          match native_runtime_for_target(target, host) {
            Ok(runtime) => render_native_launch_session(target, runtime)
            Err(problems) =>
              fail(render_problems("Lepusa launch session", problems))
          }
        Err(problems) =>
          fail(render_problems("Lepusa launch session", problems))
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
            render_handler_coverage(host) +
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
fn render_handler_coverage(host : @runtime.RuntimeHost) -> String {
  let declared = host.plan().command_routes()
  let registered = host.registry().routes()
  let missing : Array[String] = []
  for route in declared {
    if !registered.contains(route) {
      missing.push(route)
    }
  }
  if missing.is_empty() {
    "[ok] handlers: registered=\{registered.length()} missing=0\n"
  } else {
    "[warn] handlers: registered=\{registered.length()} missing=\{missing.length()} routes=\{missing.join(",")}\n"
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
fn render_native_launch_session(
  target : @lepusa.BundleTarget,
  runtime : @runtime.NativeRuntime,
) -> CliResult {
  match target {
    MacOS =>
      match @macos_backend.run(runtime) {
        Ok(result) => ok(result.plan().launch_session().to_json() + "\n")
        Err(problems) =>
          fail(render_problems("Lepusa launch session", problems))
      }
    Windows =>
      match @windows_backend.run(runtime) {
        Ok(result) => ok(result.launch_session().to_json() + "\n")
        Err(problems) =>
          fail(render_problems("Lepusa launch session", problems))
      }
    Linux =>
      match @linux_backend.run(runtime) {
        Ok(result) => ok(result.launch_session().to_json() + "\n")
        Err(problems) =>
          fail(render_problems("Lepusa launch session", problems))
      }
  }
}

///|
fn render_native_runner_plan(runtime : @runtime.NativeRuntime) -> CliResult {
  ok(runtime.bootstrap_json() + "\n")
}
