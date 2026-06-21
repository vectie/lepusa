///|
async fn render_verify_async(args : Array[String]) -> CliResult {
  let values = positional_args(args)
  let strict = has_flag(args, "--strict")
  let json = has_flag(args, "--json")
  match parse_bundle_target(values.get(0)) {
    Ok(target) =>
      match project_runtime_host(args) {
        Ok(host) =>
          match project_bundle_plan(args, target) {
            Ok(bundle) =>
              render_verify_project(target, host, bundle, strict~, json~)
            Err(problems) => fail(render_problems("Lepusa verify", problems))
          }
        Err(problems) => fail(render_problems("Lepusa verify", problems))
      }
    Err(problem) => fail(problem + "\n")
  }
}

///|
async fn render_verify_project(
  target : @lepusa.BundleTarget,
  host : @runtime.RuntimeHost,
  bundle : @lepusa.BundlePlan,
  strict~ : Bool,
  json~ : Bool,
) -> CliResult {
  let lines : Array[String] = ["Lepusa verify\n", "target: \{target.name()}\n"]
  if strict {
    lines.push("mode: strict\n")
  }
  let mut passed = true
  passed = verify_runtime_plan(host, lines) && passed
  passed = verify_dev_plan(host, lines) && passed
  passed = verify_launch_manifest(host, lines) && passed
  passed = verify_webview_content(host, lines) && passed
  let audit = host.audit()
  passed = verify_runtime_audit(audit, lines, strict~) && passed
  passed = verify_native_session(target, host, lines, strict~) && passed
  passed = verify_bundle_contract(bundle, lines) && passed
  passed = verify_release_readiness(bundle, lines, strict~) && passed
  let output = if json {
    render_verify_json(target, strict~, passed~, lines~, audit~, bundle~) + "\n"
  } else {
    lines.join("")
  }
  if passed {
    ok(output)
  } else {
    fail(output)
  }
}

///|
fn render_verify_json(
  target : @lepusa.BundleTarget,
  strict~ : Bool,
  passed~ : Bool,
  lines~ : Array[String],
  audit~ : @lepusa.RuntimeAudit,
  bundle~ : @lepusa.BundlePlan,
) -> String {
  [
    "{",
    "\"target\":\{cli_json_string(target.name())},",
    "\"strict\":\{cli_json_bool(strict)},",
    "\"ok\":\{cli_json_bool(passed)},",
    "\"audit\":\{audit.to_json()},",
    "\"releaseReadiness\":\{render_release_readiness_json(bundle)},",
    "\"lines\":[\{lines.map(fn(line) { cli_json_string(line.trim().to_owned()) }).join(",")}]",
    "}",
  ].join("")
}

///|
fn cli_json_bool(value : Bool) -> String {
  if value {
    "true"
  } else {
    "false"
  }
}

///|
fn verify_runtime_plan(
  host : @runtime.RuntimeHost,
  lines : Array[String],
) -> Bool {
  let plan = host.plan()
  lines.push(
    "[ok] plan: windows=\{plan.window_count()} routes=\{plan.command_routes().length()} capabilities=\{plan.capability_count()}\n",
  )
  true
}

///|
fn verify_dev_plan(host : @runtime.RuntimeHost, lines : Array[String]) -> Bool {
  match host.dev_plan() {
    Ok(dev) => {
      lines.push(
        "[ok] dev: webviews=\{dev.webviews().length()} startup=\{dev.startup_operations().length()} lifecycle=\{dev.lifecycle_steps().length()} bridge-sync=\{dev.bridge_sync_routes().length()} bridge-async=\{dev.bridge_async_routes().length()}\n",
      )
      true
    }
    Err(problems) => {
      lines.push(render_problem_lines(problems))
      false
    }
  }
}

///|
fn verify_launch_manifest(
  host : @runtime.RuntimeHost,
  lines : Array[String],
) -> Bool {
  match host.launch_manifest() {
    Ok(manifest) => {
      lines.push(
        "[ok] manifest: webviews=\{manifest.webviews().length()} routes=\{manifest.command_routes().length()} local-services=\{manifest.local_services().length()} filesystem-scopes=\{manifest.file_system_scopes().length()}\n",
      )
      let bridge_asset = host.resolve_asset_json(manifest.bridge_url())
      if bridge_asset.contains("\"ok\":true") {
        lines.push("[ok] asset: bridge \{manifest.bridge_url()}\n")
        true
      } else {
        lines.push("[fail] asset: bridge \{manifest.bridge_url()}\n")
        false
      }
    }
    Err(problems) => {
      lines.push(render_problem_lines(problems))
      false
    }
  }
}

///|
enum VerifiedContent {
  Checked
  Skipped
} derive(Debug, Eq)

///|
async fn verify_webview_content(
  host : @runtime.RuntimeHost,
  lines : Array[String],
) -> Bool {
  match host.snapshot() {
    Ok(session) => {
      let mut passed = true
      let mut checked = 0
      let mut skipped = 0
      for window in session.windows() {
        match verify_window_content(session, window) {
          Ok(Checked) => checked += 1
          Ok(Skipped) => skipped += 1
          Err(problem) => {
            lines.push("[fail] content: \{problem}\n")
            passed = false
          }
        }
      }
      if passed {
        lines.push(
          "[ok] content: windows=\{session.windows().length()} checked=\{checked} skipped=\{skipped}\n",
        )
      }
      passed
    }
    Err(problems) => {
      lines.push(render_problem_lines(problems))
      false
    }
  }
}

///|
async fn verify_window_content(
  session : @runtime.RuntimeSession,
  window : @runtime.RuntimeWindow,
) -> Result[VerifiedContent, String] {
  let url = window.url()
  if url.has_prefix("http://") || url.has_prefix("https://") {
    return Ok(Skipped)
  }
  if url.has_prefix("data:") {
    if url.trim() == "data:" {
      Err("window \{window.label()} has blank data url")
    } else {
      Ok(Checked)
    }
  } else if url.has_prefix("file://") {
    verify_file_content(window.label(), url[7:].to_owned())
  } else {
    match session.resolve_asset(url) {
      Ok(asset) => verify_asset_content(window.label(), asset)
      Err(problem) => Err("window \{window.label()} asset failed: \{problem}")
    }
  }
}

///|
async fn verify_asset_content(
  window_label : String,
  asset : @runtime.RuntimeAssetResponse,
) -> Result[VerifiedContent, String] {
  match asset.body() {
    VirtualContent(content) =>
      if content.trim() == "" {
        Err("window \{window_label} has blank virtual asset: \{asset.url()}")
      } else {
        Ok(Checked)
      }
    LocalFile(path) | PackagedFile(path) =>
      verify_file_content(window_label, path)
  }
}

///|
async fn verify_file_content(
  window_label : String,
  path : String,
) -> Result[VerifiedContent, String] {
  let text = @fs.read_file(path).text() catch {
    error =>
      return Err("window \{window_label} file is unreadable: \{path}: \{error}")
  }
  if text.trim() == "" {
    Err("window \{window_label} file is blank: \{path}")
  } else {
    Ok(Checked)
  }
}

///|
fn verify_native_session(
  target : @lepusa.BundleTarget,
  host : @runtime.RuntimeHost,
  lines : Array[String],
  strict~ : Bool,
) -> Bool {
  match native_runtime_for_target(target, host) {
    Ok(runtime) =>
      match verify_native_dry_run(target, runtime) {
        Ok(session) => {
          lines.push(verify_native_session_summary(target, session))
          verify_release_launch_gate(target, session, lines, strict~)
        }
        Err(problems) => {
          lines.push(render_problem_lines(problems))
          false
        }
      }
    Err(problems) => {
      lines.push(render_problem_lines(problems))
      false
    }
  }
}

///|
fn verify_native_dry_run(
  target : @lepusa.BundleTarget,
  runtime : @runtime.NativeRuntime,
) -> Result[@runtime.NativeLaunchSession, Array[String]] {
  match target {
    MacOS =>
      match @macos_backend.run(runtime) {
        Ok(result) => {
          let session = result.plan().launch_session()
          Ok(session)
        }
        Err(problems) => Err(problems)
      }
    Windows =>
      match @windows_backend.run(runtime) {
        Ok(result) => Ok(result.launch_session())
        Err(problems) => Err(problems)
      }
    Linux =>
      match @linux_backend.run(runtime) {
        Ok(result) => Ok(result.launch_session())
        Err(problems) => Err(problems)
      }
  }
}

///|
fn verify_native_session_summary(
  target : @lepusa.BundleTarget,
  session : @runtime.NativeLaunchSession,
) -> String {
  let target_can_launch = session.can_launch_with_capability(
    native_launch_capability_for_target(target),
  )
  "[ok] native-session: webviews=\{session.webviews().length()} startup=\{session.execution().startup_operations().length()} lifecycle=\{session.execution().lifecycle_steps().length()} scheduler-can-launch=\{session.can_launch()} target-can-launch=\{target_can_launch}\n"
}

///|
fn verify_runtime_audit(
  audit : @lepusa.RuntimeAudit,
  lines : Array[String],
  strict~ : Bool,
) -> Bool {
  let missing = audit_findings_by_kind(audit, RuntimeAuditMissingHandler)
  lines.push(render_handler_coverage_from_audit(audit, missing))
  lines.push(render_route_exposure_from_audit(audit))
  if audit.ok() {
    lines.push(
      "[ok] audit: errors=0 warnings=\{audit.warning_count()} info=\{audit.info_count()}\n",
    )
    true
  } else if strict {
    if !missing.is_empty() {
      lines.push(
        "[fail] strict: missing concrete handlers for \{missing.length()} route(s)\n",
      )
    }
    let other_errors = audit.error_count() - missing.length()
    if other_errors > 0 {
      lines.push("[fail] strict: runtime audit errors=\{other_errors}\n")
    }
    false
  } else {
    lines.push(
      "[warn] audit: errors=\{audit.error_count()} warnings=\{audit.warning_count()} info=\{audit.info_count()}\n",
    )
    true
  }
}

///|
fn render_route_exposure_from_audit(audit : @lepusa.RuntimeAudit) -> String {
  let exposures = audit.route_exposures()
  let exposed = audit.exposed_routes()
  let omitted = exposures.length() - exposed.length()
  "[ok] exposure: declared=\{exposures.length()} exposed=\{exposed.length()} omitted=\{omitted}\n"
}

///|
fn missing_handler_routes(host : @runtime.RuntimeHost) -> Array[String] {
  audit_findings_by_kind(host.audit(), RuntimeAuditMissingHandler).map(fn(
    finding,
  ) {
    finding.route()
  })
}

///|
fn audit_findings_by_kind(
  audit : @lepusa.RuntimeAudit,
  kind : @lepusa.RuntimeAuditKind,
) -> Array[@lepusa.RuntimeAuditFinding] {
  audit.findings().filter(fn(finding) { finding.kind() == kind })
}

///|
fn render_handler_coverage_from_audit(
  audit : @lepusa.RuntimeAudit,
  missing : Array[@lepusa.RuntimeAuditFinding],
) -> String {
  let registered = audit.registered_routes()
  if missing.is_empty() {
    "[ok] handlers: registered=\{registered.length()} missing=0\n"
  } else {
    let routes = missing.map(fn(finding) { finding.route() })
    "[warn] handlers: registered=\{registered.length()} missing=\{missing.length()} routes=\{routes.join(",")}\n"
  }
}

///|
fn verify_release_launch_gate(
  target : @lepusa.BundleTarget,
  session : @runtime.NativeLaunchSession,
  lines : Array[String],
  strict~ : Bool,
) -> Bool {
  match
    session.launch_blocker_with_capability(
      verify_target_display_name(target),
      native_launch_capability_for_target(target),
    ) {
    Some(problem) =>
      if strict {
        lines.push("[fail] strict: \{problem}\n")
        false
      } else {
        lines.push("[warn] native-launch: \{problem}\n")
        true
      }
    None => {
      if strict {
        lines.push("[ok] strict: native launch gate passed\n")
      }
      true
    }
  }
}

///|
fn verify_target_display_name(target : @lepusa.BundleTarget) -> String {
  match target {
    MacOS => "macOS"
    Windows => "Windows"
    Linux => "Linux"
  }
}

///|
fn verify_bundle_contract(
  bundle : @lepusa.BundlePlan,
  lines : Array[String],
) -> Bool {
  match bundle.files() {
    Ok(files) =>
      match bundle.runtime_manifest() {
        Ok(manifest) => {
          lines.push(
            "[ok] bundle: files=\{files.length()} resources=\{bundle.resources().length()} runtime-webviews=\{manifest.webviews().length()} signing-prerequisites=\{bundle.signing_prerequisites().length()}\n",
          )
          true
        }
        Err(problems) => {
          lines.push(render_problem_lines(problems))
          false
        }
      }
    Err(problems) => {
      lines.push(render_problem_lines(problems))
      false
    }
  }
}

///|
fn verify_release_readiness(
  bundle : @lepusa.BundlePlan,
  lines : Array[String],
  strict~ : Bool,
) -> Bool {
  match bundle.release_readiness() {
    Ok(report) =>
      if report.ready() {
        lines.push(
          "[ok] release-readiness: ready=true artifacts=\{report.artifacts()} required-runtime-dependencies=\{report.required_runtime_dependencies()}\n",
        )
        true
      } else {
        let issues = report.issues().join("; ")
        if strict {
          lines.push(
            "[fail] strict: release-readiness ready=false issues=\{issues}\n",
          )
          false
        } else {
          lines.push("[warn] release-readiness: ready=false issues=\{issues}\n")
          true
        }
      }
    Err(problems) => {
      lines.push(
        "[fail] release-readiness: ready=false issues=\{problems.join("; ")}\n",
      )
      false
    }
  }
}

///|
fn render_problem_lines(problems : Array[String]) -> String {
  problems.map(fn(problem) { "[fail] \{problem}\n" }).join("")
}
