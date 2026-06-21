///|
async fn render_doctor_async(args : Array[String]) -> CliResult {
  let values = positional_args(args)
  let json = has_flag(args, "--json")
  match parse_bundle_target(values.get(0)) {
    Ok(target) =>
      match project_runtime_host(args) {
        Ok(host) =>
          match project_bundle_plan(args, target) {
            Ok(bundle) => render_doctor_host(host, bundle, json~)
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
  let json = has_flag(args, "--json")
  match parse_bundle_target(values.get(0)) {
    Ok(target) =>
      match project_runtime_host(args) {
        Ok(host) =>
          match native_runtime_for_target(target, host) {
            Ok(runtime) =>
              if has_flag(args, "--launch") {
                render_native_launch(target, runtime, json~)
              } else {
                render_native_run_summary(target, runtime, json~)
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
            Ok(runtime) =>
              render_native_launch_session(
                target,
                runtime,
                bridge_mode=target_bridge_mode_from_args(args, target),
                requested_bridge_mode=bridge_mode_from_args(args),
              )
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
  json~ : Bool,
) -> CliResult {
  let plan = host.plan()
  match host.launch_manifest() {
    Ok(manifest) =>
      match bundle.files() {
        Ok(files) =>
          if json {
            ok(render_doctor_json(host, bundle, manifest, files) + "\n")
          } else {
            ok(
              "Lepusa doctor\n" +
              "[ok] public-api: root package can build launch/runtime plans\n" +
              "[ok] runtime: backend=\{plan.backend().name()} protocol=\{plan.asset_protocol()}\n" +
              "[ok] manifest: webviews=\{manifest.webviews().length()} routes=\{manifest.command_routes().length()}\n" +
              "[ok] ipc: routes=\{plan.command_routes().length()}\n" +
              render_handler_coverage(host) +
              "[ok] bundle: target=\{bundle.target().name()} files=\{files.length()} resources=\{bundle.resources().length()}\n" +
              render_release_readiness(bundle) +
              "[ok] runtime-dependencies: count=\{bundle.runtime_dependencies().length()}\n" +
              render_doctor_native_launch_gate(bundle.target(), host) +
              "[ok] signing: prerequisites=\{bundle.signing_prerequisites().length()}\n" +
              render_signing_prerequisites(bundle) +
              render_native_backend_diagnostics(),
            )
          }
        Err(problems) => fail(render_problems("Lepusa doctor", problems))
      }
    Err(problems) => fail(render_problems("Lepusa doctor", problems))
  }
}

///|
fn render_doctor_json(
  host : @runtime.RuntimeHost,
  bundle : @lepusa.BundlePlan,
  manifest : @lepusa.RuntimeLaunchManifest,
  files : Array[@lepusa.BundleFile],
) -> String {
  let plan = host.plan()
  [
    "{",
    "\"target\":\{cli_json_string(bundle.target().name())},",
    "\"publicApi\":true,",
    "\"runtime\":{\"backend\":\{cli_json_string(plan.backend().name())},\"protocol\":\{cli_json_string(plan.asset_protocol())}},",
    "\"manifest\":{\"webviews\":\{manifest.webviews().length()},\"routes\":\{manifest.command_routes().length()}},",
    "\"ipc\":{\"routes\":\{plan.command_routes().length()}},",
    "\"handlers\":\{render_handler_coverage_json(host)},",
    "\"bundle\":{\"target\":\{cli_json_string(bundle.target().name())},\"files\":\{files.length()},\"resources\":\{bundle.resources().length()},\"runtimeDependencies\":[\{bundle.runtime_dependencies().map(fn(dependency) { dependency.to_json() }).join(",")}]},",
    "\"releaseReadiness\":\{render_release_readiness_json(bundle)},",
    "\"nativeLaunch\":\{render_doctor_native_launch_json(bundle.target(), host)},",
    "\"signing\":{\"prerequisites\":[\{bundle.signing_prerequisites().map(fn(item) { item.to_json() }).join(",")}]},",
    "\"platforms\":[\{render_native_backend_diagnostics_json()}]",
    "}",
  ].join("")
}

///|
fn render_release_readiness(bundle : @lepusa.BundlePlan) -> String {
  match bundle.release_readiness() {
    Ok(report) => {
      let status = if report.ready() { "ok" } else { "warn" }
      let issues = if report.issues().is_empty() {
        ""
      } else {
        " issues=\{report.issues().join("; ")}"
      }
      "[\{status}] release-readiness: ready=\{report.ready()} artifacts=\{report.artifacts()} required-runtime-dependencies=\{report.required_runtime_dependencies()}\{issues}\n"
    }
    Err(problems) =>
      "[warn] release-readiness: ready=false issues=\{problems.join("; ")}\n"
  }
}

///|
fn render_release_readiness_json(bundle : @lepusa.BundlePlan) -> String {
  match bundle.release_readiness() {
    Ok(report) => report.to_json()
    Err(problems) =>
      [
        "{",
        "\"target\":\{cli_json_string(bundle.target().name())},",
        "\"ready\":false,",
        "\"issues\":[\{problems.map(fn(problem) { cli_json_string(problem) }).join(",")}]",
        "}",
      ].join("")
  }
}

///|
fn render_doctor_native_launch_gate(
  target : @lepusa.BundleTarget,
  host : @runtime.RuntimeHost,
) -> String {
  match native_runtime_for_target(target, host) {
    Ok(runtime) => {
      let contract = native_backend_contract_for_target(target, runtime)
      match verify_native_dry_run(target, runtime) {
        Ok(session) => {
          let base = "target=\{target.name()} webviews=\{session.webviews().length()} startup=\{session.execution().startup_operations().length()} lifecycle=\{session.execution().lifecycle_steps().length()}"
          if contract.can_launch() {
            "[ok] native-launch: \{base} can-launch=true contract-ok=true\n"
          } else {
            "[warn] native-launch: \{base} can-launch=false contract-ok=false reason=\{native_contract_blocker(contract)}\n"
          }
        }
        Err(problems) =>
          "[warn] native-launch: target=\{target.name()} can-launch=false reason=\{problems.join("; ")}\n"
      }
    }
    Err(problems) =>
      "[warn] native-launch: target=\{target.name()} can-launch=false reason=\{problems.join("; ")}\n"
  }
}

///|
fn render_doctor_native_launch_json(
  target : @lepusa.BundleTarget,
  host : @runtime.RuntimeHost,
) -> String {
  match native_runtime_for_target(target, host) {
    Ok(runtime) => {
      let contract = native_backend_contract_for_target(target, runtime)
      match verify_native_dry_run(target, runtime) {
        Ok(session) => {
          let blocker = if contract.can_launch() {
            None
          } else {
            Some(native_contract_blocker(contract))
          }
          let blocker_json = match blocker {
            Some(problem) => cli_json_string(problem)
            None => "null"
          }
          [
            "{",
            "\"ok\":true,",
            "\"target\":\{cli_json_string(target.name())},",
            "\"webviews\":\{session.webviews().length()},",
            "\"startup\":\{session.execution().startup_operations().length()},",
            "\"lifecycle\":\{session.execution().lifecycle_steps().length()},",
            "\"canLaunch\":\{cli_json_bool(contract.can_launch())},",
            "\"blocker\":\{blocker_json},",
            "\"backendContract\":\{contract.to_json()}",
            "}",
          ].join("")
        }
        Err(problems) =>
          render_doctor_native_launch_error_json(target, problems)
      }
    }
    Err(problems) => render_doctor_native_launch_error_json(target, problems)
  }
}

///|
fn render_doctor_native_launch_error_json(
  target : @lepusa.BundleTarget,
  problems : Array[String],
) -> String {
  [
    "{",
    "\"ok\":false,",
    "\"target\":\{cli_json_string(target.name())},",
    "\"webviews\":0,",
    "\"startup\":0,",
    "\"lifecycle\":0,",
    "\"canLaunch\":false,",
    "\"blocker\":\{cli_json_string(problems.join("; "))}",
    "}",
  ].join("")
}

///|
fn render_handler_coverage(host : @runtime.RuntimeHost) -> String {
  let audit = host.audit()
  render_handler_coverage_from_audit(
    audit,
    audit_findings_by_kind(audit, RuntimeAuditMissingHandler),
  )
}

///|
fn render_handler_coverage_json(host : @runtime.RuntimeHost) -> String {
  let declared = handler_required_routes(host)
  let registered = host.registry().routes()
  let missing = missing_handler_routes(host)
  [
    "{",
    "\"registered\":\{registered.length()},",
    "\"required\":\{declared.length()},",
    "\"missing\":\{missing.length()},",
    "\"missingRoutes\":[\{missing.map(fn(route) { cli_json_string(route) }).join(",")}]",
    "}",
  ].join("")
}

///|
fn handler_required_routes(host : @runtime.RuntimeHost) -> Array[String] {
  match host.dev_plan() {
    Ok(dev) => {
      let routes = dev.bridge_sync_routes()
      for route in dev.bridge_async_routes() {
        routes.push(route)
      }
      routes
    }
    Err(_) => host.plan().command_routes()
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
    render_native_preflight_line(@macos_backend.preflight()),
    render_native_backend_line("windows", @windows_backend.detect()),
    render_native_preflight_line(@windows_backend.preflight()),
    render_native_backend_line("linux", @linux_backend.detect()),
    render_native_preflight_line(@linux_backend.preflight()),
  ].join("")
}

///|
fn render_native_backend_diagnostics_json() -> String {
  [
    render_native_backend_json(
      "macos",
      @macos_backend.detect(),
      @macos_backend.preflight(),
    ),
    render_native_backend_json(
      "windows",
      @windows_backend.detect(),
      @windows_backend.preflight(),
    ),
    render_native_backend_json(
      "linux",
      @linux_backend.detect(),
      @linux_backend.preflight(),
    ),
  ].join(",")
}

///|
fn render_native_backend_json(
  platform : String,
  backend : Result[@runtime.NativeBackend, String],
  preflight : @runtime.NativeBackendPreflight,
) -> String {
  let (available, engine, problem) = match backend {
    Ok(backend) => (true, backend.webview_engine(), "")
    Err(problem) => (false, "", problem)
  }
  [
    "{",
    "\"platform\":\{cli_json_string(platform)},",
    "\"available\":\{cli_json_bool(available)},",
    "\"engine\":\{cli_json_string(engine)},",
    "\"problem\":\{cli_json_string(problem)},",
    "\"preflight\":\{preflight.to_json()}",
    "}",
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
fn render_native_preflight_line(
  preflight : @runtime.NativeBackendPreflight,
) -> String {
  let status = if preflight.can_launch() { "ok" } else { "warn" }
  let reason = if preflight.problem() == "" {
    ""
  } else {
    " reason=\{preflight.problem()}"
  }
  "[\{status}] platform-detail: \{preflight.platform()} \{preflight.dependency_name()}=\{preflight.dependency_available().to_string()} creation-loop=\{preflight.webview_creation_loop().to_string()} sync-bridge=\{preflight.sync_bridge_evaluate().to_string()} async-bridge=\{preflight.async_bridge_drain().to_string()} can-launch=\{preflight.can_launch().to_string()}\{reason}\n"
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
  json~ : Bool,
) -> CliResult {
  match target {
    MacOS =>
      match @macos_backend.launch(runtime) {
        Ok(result) =>
          render_native_run_report(
            "Lepusa launch",
            macos_launch_report(target, runtime, result),
            json~,
          )
        Err(problems) => fail(render_problems("Lepusa launch", problems))
      }
    Windows =>
      match @windows_backend.launch(runtime) {
        Ok(result) =>
          render_native_run_report(
            "Lepusa launch",
            native_run_report(target, runtime, status=result.status()),
            json~,
          )
        Err(problems) => fail(render_problems("Lepusa launch", problems))
      }
    Linux =>
      match @linux_backend.launch(runtime) {
        Ok(result) =>
          render_native_run_report(
            "Lepusa launch",
            native_run_report(target, runtime, status=result.status()),
            json~,
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
    execution_report=Some(
      native_operation_execution_report(target, plan.execution()),
    ),
    bridge_sync_routes=plan.bridge().sync_command_routes().length(),
    bridge_async_routes=plan.bridge().async_command_routes().length(),
    target_can_launch=native_status_target_can_launch(result.status()),
    target_launch_blocker=native_status_target_launch_blocker(result.status()),
  )
}

///|
fn native_run_report(
  target : @lepusa.BundleTarget,
  runtime : @runtime.NativeRuntime,
  status? : @lepusa.RunStatus = RunPrepared,
) -> @lepusa.RunReport {
  let (can_launch, blocker) = native_target_launch_status(target, runtime)
  runtime.run_report(
    target=target.name(),
    status~,
    execution_report=Some(
      native_operation_execution_report(
        target,
        runtime.runner_plan().execution_plan(),
      ),
    ),
    target_can_launch=can_launch,
    target_launch_blocker=blocker,
  )
}

///|
fn native_operation_execution_report(
  target : @lepusa.BundleTarget,
  execution : @runtime.NativeExecutionPlan,
) -> @runtime.NativeOperationExecutionReport {
  match target {
    MacOS => @macos_backend.operation_executor().execute_startup(execution)
    Windows => @windows_backend.operation_executor().execute_startup(execution)
    Linux => @linux_backend.operation_executor().execute_startup(execution)
  }
}

///|
fn native_status_target_can_launch(status : @lepusa.RunStatus) -> Bool {
  !(status is RunUnsupported(_))
}

///|
fn native_status_target_launch_blocker(status : @lepusa.RunStatus) -> String {
  match status {
    RunUnsupported(message) => message
    _ => ""
  }
}

///|
fn native_target_launch_status(
  target : @lepusa.BundleTarget,
  runtime : @runtime.NativeRuntime,
) -> (Bool, String) {
  let contract = native_backend_contract_for_target(target, runtime)
  match verify_native_dry_run(target, runtime) {
    Ok(_) =>
      if contract.can_launch() {
        (true, "")
      } else {
        (false, native_contract_blocker(contract))
      }
    Err(problems) => (false, problems.join("; "))
  }
}

///|
fn native_backend_contract_for_target(
  target : @lepusa.BundleTarget,
  runtime : @runtime.NativeRuntime,
) -> @runtime.NativeBackendContract {
  runtime.backend_contract(
    capability=native_launch_capability_for_target(target),
    platform_name=verify_target_display_name(target),
  )
}

///|
fn native_contract_blocker(contract : @runtime.NativeBackendContract) -> String {
  match contract.launch_blocker() {
    Some(message) => message
    None =>
      match contract.problems().get(0) {
        Some(problem) => problem
        None => ""
      }
  }
}

///|
fn render_native_run_report(
  title : String,
  report : @lepusa.RunReport,
  json? : Bool = false,
  include_status? : Bool = true,
  include_bridge_url? : Bool = false,
  include_services? : Bool = false,
) -> CliResult {
  if json {
    return ok(report.to_json() + "\n")
  }
  let status = if include_status {
    "status: \{report.status().name()}\n"
  } else {
    ""
  }
  let status_message = if include_status && report.status().message() != "" {
    "status-message: \{report.status().message()}\n"
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
  let execution = if report.executable_operations() == 0 &&
    report.failed_operations() == 0 {
    ""
  } else {
    "executable-operations: \{report.executable_operations()}\n" +
    "executed-operations: \{report.executed_operations()}\n" +
    "skipped-operations: \{report.skipped_operations()}\n" +
    "failed-operations: \{report.failed_operations()}\n" +
    (if report.first_execution_failure() == "" {
      ""
    } else {
      "first-execution-failure: \{report.first_execution_failure()}\n"
    })
  }
  ok(
    title +
    "\n" +
    "target: \{report.target()}\n" +
    "backend: \{report.backend()}\n" +
    "engine: \{report.engine()}\n" +
    status +
    status_message +
    "webviews: \{report.webviews()}\n" +
    "first-window-url: \{report.first_window_url()}\n" +
    "target-can-launch: \{report.target_can_launch()}\n" +
    (if report.target_launch_blocker() == "" {
      ""
    } else {
      "target-launch-blocker: \{report.target_launch_blocker()}\n"
    }) +
    load_url +
    bridge_url +
    services +
    "startup-operations: \{report.startup_operations()}\n" +
    "lifecycle-steps: \{report.lifecycle_steps()}\n" +
    execution +
    bridge_routes,
  )
}

///|
fn render_native_run_summary(
  target : @lepusa.BundleTarget,
  runtime : @runtime.NativeRuntime,
  json~ : Bool,
) -> CliResult {
  render_native_run_report(
    "Lepusa run",
    native_run_report(target, runtime),
    json~,
    include_status=false,
    include_bridge_url=true,
    include_services=true,
  )
}

///|
fn render_native_launch_session(
  target : @lepusa.BundleTarget,
  runtime : @runtime.NativeRuntime,
  bridge_mode? : @runtime.NativeBridgeSchedulerMode = NativeBridgeSyncOnly,
  requested_bridge_mode~ : @runtime.NativeBridgeSchedulerMode,
) -> CliResult {
  match target {
    MacOS =>
      match @macos_backend.run(runtime) {
        Ok(result) =>
          ok(
            native_launch_readiness(
              target,
              result.plan().launch_session(bridge_mode~),
              requested_bridge_mode~,
            ).to_json() +
            "\n",
          )
        Err(problems) =>
          fail(render_problems("Lepusa launch session", problems))
      }
    Windows =>
      match @windows_backend.run(runtime) {
        Ok(result) =>
          ok(
            native_launch_readiness(
              target,
              result.launch_session(bridge_mode~),
              requested_bridge_mode~,
            ).to_json() +
            "\n",
          )
        Err(problems) =>
          fail(render_problems("Lepusa launch session", problems))
      }
    Linux =>
      match @linux_backend.run(runtime) {
        Ok(result) =>
          ok(
            native_launch_readiness(
              target,
              result.launch_session(bridge_mode~),
              requested_bridge_mode~,
            ).to_json() +
            "\n",
          )
        Err(problems) =>
          fail(render_problems("Lepusa launch session", problems))
      }
  }
}

///|
fn native_launch_readiness(
  target : @lepusa.BundleTarget,
  session : @runtime.NativeLaunchSession,
  requested_bridge_mode~ : @runtime.NativeBridgeSchedulerMode,
) -> @runtime.NativeLaunchReadiness {
  @runtime.NativeLaunchReadiness::new(
    target=target.name(),
    platform_name=verify_target_display_name(target),
    session~,
    capability=native_launch_capability_for_target(target),
    preflight=native_backend_preflight_for_target(target),
    requested_bridge_mode~,
  )
}

///|
fn bridge_mode_from_args(
  args : Array[String],
) -> @runtime.NativeBridgeSchedulerMode {
  if has_flag(args, "--async-bridge") {
    NativeBridgeAsyncCapable
  } else {
    NativeBridgeSyncOnly
  }
}

///|
fn target_bridge_mode_from_args(
  args : Array[String],
  target : @lepusa.BundleTarget,
) -> @runtime.NativeBridgeSchedulerMode {
  if has_flag(args, "--async-bridge") {
    native_launch_capability_for_target(target).bridge_mode()
  } else {
    NativeBridgeSyncOnly
  }
}

///|
fn native_launch_capability_for_target(
  target : @lepusa.BundleTarget,
) -> @runtime.NativeLaunchCapability {
  match target {
    MacOS => @macos_backend.launch_capability()
    Windows => @windows_backend.launch_capability()
    Linux => @linux_backend.launch_capability()
  }
}

///|
fn native_backend_preflight_for_target(
  target : @lepusa.BundleTarget,
) -> @runtime.NativeBackendPreflight {
  match target {
    MacOS => @macos_backend.preflight()
    Windows => @windows_backend.preflight()
    Linux => @linux_backend.preflight()
  }
}

///|
fn render_native_runner_plan(runtime : @runtime.NativeRuntime) -> CliResult {
  ok(runtime.bootstrap_json() + "\n")
}
